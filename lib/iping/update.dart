import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_installer.dart';

const ipingUpdateBase = String.fromEnvironment(
  'IPING_UPDATE_BASE_URL',
  defaultValue: 'https://video.iping.my/releases/',
);

class IpingUpdate {
  const IpingUpdate({
    required this.version,
    required this.buildNumber,
    required this.url,
    required this.sha256,
    required this.size,
    required this.format,
    this.notes = '',
  });

  final String version;
  final int buildNumber;
  final Uri url;
  final String sha256;
  final int size;
  final String format;
  final String notes;

  factory IpingUpdate.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String;
    final build = json['buildNumber'] as int;
    final url = Uri.parse(json['url'] as String);
    final hash = json['sha256'] as String;
    final size = json['size'] as int;
    final format = json['format'] as String;
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        build <= 0 ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        size <= 0 ||
        !const {
          'apk',
          'exe',
          'zip',
          'deb',
          'rpm',
          'AppImage',
        }.contains(format)) {
      throw const FormatException('Invalid update metadata');
    }
    return IpingUpdate(
      version: version,
      buildNumber: build,
      url: url,
      sha256: hash,
      size: size,
      format: format,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, Object> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'url': url.toString(),
    'sha256': sha256,
    'size': size,
    'format': format,
    'notes': notes,
  };

  bool isNewerThan(PackageInfo current) {
    final compared = compareVersions(version, current.version);
    return compared > 0 ||
        (compared == 0 &&
            buildNumber > (int.tryParse(current.buildNumber) ?? 0));
  }
}

String ipingUpdateArch(Abi abi) => switch (abi) {
  Abi.androidArm ||
  Abi.androidArm64 ||
  Abi.macosArm64 ||
  Abi.linuxArm64 ||
  Abi.windowsArm64 => abi == Abi.androidArm ? 'arm' : 'arm64',
  Abi.androidX64 || Abi.macosX64 || Abi.linuxX64 || Abi.windowsX64 => 'amd64',
  _ => throw UnsupportedError('Unsupported update architecture: $abi'),
};

class IpingUpdateClient {
  IpingUpdateClient({Dio? dio, this.baseUrl = ipingUpdateBase})
    : dio = dio ?? Dio();

  final Dio dio;
  final String baseUrl;
  final _cancel = CancelToken();

  Future<IpingUpdate?> check(String target, PackageInfo current) async {
    final response = await dio.get<Map<String, dynamic>>(
      Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/latest.json',
      ).toString(),
      cancelToken: _cancel,
      options: Options(
        responseType: ResponseType.json,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {HttpHeaders.cacheControlHeader: 'no-cache'},
      ),
    );
    final json = response.data!;
    if (json['schemaVersion'] != 1 || json['packageId'] != packageName) {
      throw const FormatException('Unexpected update manifest');
    }
    final assets = json['assets'] as Map<String, dynamic>;
    final asset = assets[target];
    if (asset == null) throw FormatException('No update artifact for $target');
    final update = IpingUpdate.fromJson({
      ...json,
      ...Map<String, dynamic>.from(asset as Map),
    });
    return update.isNewerThan(current) ? update : null;
  }

  Future<File> download(
    IpingUpdate update,
    void Function(double progress) onProgress,
  ) async {
    final temp = await getTemporaryDirectory();
    final directory = await temp.createTemp('iping-update-');
    final file = File(p.join(directory.path, 'update.${update.format}'));
    try {
      await dio.downloadUri(
        update.url,
        '${file.path}.part',
        cancelToken: _cancel,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
        onReceiveProgress: (received, _) {
          if (received > update.size) {
            throw const FormatException('Update exceeds advertised size');
          }
          onProgress((received / update.size).clamp(0, 1));
        },
      );
      await File('${file.path}.part').rename(file.path);
      await Isolate.run(() => verifyIpingUpdate(file.path, update));
      return file;
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  void close() {
    _cancel.cancel();
    dio.close(force: true);
  }
}

Future<void> verifyIpingUpdate(String path, IpingUpdate update) async {
  final file = File(path);
  if (await file.length() != update.size ||
      (await sha256.bind(file.openRead()).first).toString() != update.sha256) {
    throw const FormatException('Update checksum mismatch');
  }
}

class IpingUpdater extends ChangeNotifier {
  IpingUpdater({
    required PackageInfo Function() current,
    required this.target,
    required this.client,
    required this.onRequired,
    required this.beforeInstall,
    required this.exitApplication,
    this.enabled = kReleaseMode && !safeModeBuild,
    Future<void> Function(IpingUpdate, void Function(double))? install,
  }) : _current = current,
       _install = install;

  final PackageInfo Function() _current;
  PackageInfo get current => _current();
  final Future<String> target;
  final IpingUpdateClient client;
  final Future<void> Function() onRequired;
  final Future<void> Function() beforeInstall;
  final Future<void> Function() exitApplication;
  final bool enabled;
  final Future<void> Function(IpingUpdate, void Function(double))? _install;
  IpingUpdate? update;
  bool busy = false;
  bool failed = false;
  double? progress;
  bool _disposed = false;
  Future<void>? _pending;
  StreamSubscription<OtaEvent>? _otaSubscription;
  Completer<void>? _otaCompletion;
  SharedPreferences? _preferences;
  String? _cacheKey;

  bool get required => update != null;

  Future<void> initialize() async {
    if (!enabled) return;
    try {
      final selected = await target;
      _preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      _cacheKey = 'iping.requiredUpdate:${client.baseUrl}:$selected';
      final cached = _preferences!.getString(_cacheKey!);
      if (cached != null) {
        final saved = IpingUpdate.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        if (saved.isNewerThan(current)) {
          update = saved;
          notifyListeners();
          await onRequired();
        } else {
          await _preferences!.remove(_cacheKey!);
        }
      }
    } catch (error) {
      commonPrint.log(
        'Unable to restore pending update: ${compactError(error)}',
      );
    }
    if (!_disposed) await check();
  }

  Future<void> check() {
    if (!enabled || _disposed || busy) return Future.value();
    return _pending ??= _check().whenComplete(() => _pending = null);
  }

  Future<void> _check() async {
    try {
      final next = await client.check(await target, current);
      if (_disposed || next == null) return;
      if (update != null &&
          compareVersions(
                '${next.version}+${next.buildNumber}',
                '${update!.version}+${update!.buildNumber}',
              ) <
              0) {
        return;
      }
      update = next;
      failed = false;
      notifyListeners();
      if (_cacheKey != null) {
        await _preferences!.setString(_cacheKey!, jsonEncode(next.toJson()));
      }
      await onRequired();
    } catch (error) {
      if (_disposed) return;
      commonPrint.log('Unable to check for updates: ${compactError(error)}');
      failed = required;
      notifyListeners();
    }
  }

  void _onProgress(double value) {
    if (_disposed) return;
    final next = (value * 100).floor() / 100;
    if (progress == next) return;
    progress = next;
    notifyListeners();
  }

  Future<void> install({PasswordPrompt? askPassword}) async {
    final release = update;
    if (release == null || busy || _disposed) return;
    busy = true;
    failed = false;
    progress = 0;
    notifyListeners();
    try {
      final install = _install;
      if (install != null) {
        await install(release, _onProgress);
      } else if (Platform.isAndroid) {
        await beforeInstall();
        final completed = Completer<void>();
        _otaCompletion = completed;
        _otaSubscription = OtaUpdate()
            .execute(
              release.url.toString(),
              destinationFilename: 'iping-${release.buildNumber}.apk',
              sha256checksum: release.sha256,
            )
            .listen(
              (event) {
                switch (event.status) {
                  case OtaStatus.DOWNLOADING:
                    _onProgress(
                      (double.tryParse(event.value ?? '') ?? 0) / 100,
                    );
                  case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
                    if (!completed.isCompleted) completed.complete();
                  default:
                    if (!completed.isCompleted) {
                      completed.completeError(
                        StateError('APK update failed: ${event.status}'),
                      );
                    }
                }
              },
              onError: (Object error) {
                if (!completed.isCompleted) completed.completeError(error);
              },
              onDone: () {
                if (!completed.isCompleted) {
                  completed.completeError(StateError('APK update interrupted'));
                }
              },
            );
        await completed.future;
      } else {
        final file = await client.download(release, _onProgress);
        if (_disposed) return;
        await beforeInstall();
        await installIpingUpdate(
          file,
          release.format,
          askPassword: askPassword,
        );
        await exitApplication();
      }
    } catch (error) {
      commonPrint.log('Unable to install update: ${compactError(error)}');
      failed = true;
    } finally {
      await _otaSubscription?.cancel();
      _otaSubscription = null;
      _otaCompletion = null;
      if (!_disposed) {
        busy = false;
        progress = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_otaCompletion case final completion? when !completion.isCompleted) {
      completion.completeError(StateError('Updater disposed'));
    }
    unawaited(_otaSubscription?.cancel());
    client.close();
    super.dispose();
  }
}
