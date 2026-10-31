import 'dart:async';
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
import 'package:url_launcher/url_launcher.dart';

import 'update_installer.dart';

const ipingUpdateBase = String.fromEnvironment(
  'IPING_UPDATE_BASE_URL',
  defaultValue: 'https://video.iping.my/releases/',
);

/// A profile build carries the same AOT code as a release one, so only debug
/// and safe mode builds skip update checks.
const ipingUpdateChecksEnabled =
    (kReleaseMode || kProfileMode) && !safeModeBuild;

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

  bool get isAppStore => format == 'app-store';

  factory IpingUpdate.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String;
    final build = json['buildNumber'] as int;
    final url = Uri.parse(json['url'] as String);
    final hash = json['sha256'] as String;
    final size = json['size'] as int;
    final format = json['format'] as String;
    final appStore = format == 'app-store';
    final validVersion = appStore
        ? RegExp(r'^\d+(?:\.\d+){0,2}$').hasMatch(version)
        : RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);
    final validPackage = appStore
        ? build == 0 &&
              hash.isEmpty &&
              size == 0 &&
              url.host == 'apps.apple.com' &&
              RegExp(r'^/app/id[1-9]\d*$').hasMatch(url.path)
        : build > 0 &&
              RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) &&
              size > 0 &&
              const {
                'apk',
                'exe',
                'zip',
                'deb',
                'rpm',
                'AppImage',
              }.contains(format);
    if (!validVersion ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        !validPackage) {
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
        (!isAppStore &&
            compared == 0 &&
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
  IpingUpdateClient({
    Dio? dio,
    this.baseUrl = ipingUpdateBase,
    this.temporaryDirectory = getTemporaryDirectory,
  }) : dio = dio ?? Dio();

  final Dio dio;
  final String baseUrl;
  final Future<Directory> Function() temporaryDirectory;
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
    final temp = await temporaryDirectory();
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
      await _verifyInIsolate(file.path, update);
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

// Isolate.run sends the closure's whole context, and a closure in download()
// would share one with onProgress, which reaches the updater and its sockets.
Future<void> _verifyInIsolate(String path, IpingUpdate update) =>
    Isolate.run(() => verifyIpingUpdate(path, update));

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
    required this.beforeInstall,
    required this.exitApplication,
    this.enabled = ipingUpdateChecksEnabled,
    Future<void> Function(IpingUpdate, void Function(double))? install,
    Future<bool> Function(Uri)? openStore,
  }) : _current = current,
       _install = install,
       _openStore = openStore ?? _launchStore;

  final PackageInfo Function() _current;
  PackageInfo get current => _current();
  final Future<String> target;
  final IpingUpdateClient client;
  final Future<void> Function() beforeInstall;
  final Future<void> Function() exitApplication;
  final bool enabled;
  final Future<void> Function(IpingUpdate, void Function(double))? _install;
  final Future<bool> Function(Uri) _openStore;
  IpingUpdate? update;
  bool busy = false;
  bool failed = false;
  double? progress;
  bool _disposed = false;
  Future<void>? _pending;
  StreamSubscription<OtaEvent>? _otaSubscription;
  Completer<void>? _otaCompletion;
  bool checkFailed = false;

  bool get checking => _pending != null;

  Future<void> check() {
    if (!enabled || _disposed || busy) return Future.value();
    if (_pending case final pending?) return pending;
    final operation = Future<void>.microtask(_check).whenComplete(() {
      _pending = null;
      if (!_disposed) notifyListeners();
    });
    _pending = operation;
    checkFailed = false;
    notifyListeners();
    return operation;
  }

  Future<void> _check() async {
    try {
      final next = await client.check(await target, current);
      if (_disposed) return;
      update = next;
      failed = false;
    } catch (error) {
      if (_disposed) return;
      commonPrint.log('Unable to check for updates: ${compactError(error)}');
      checkFailed = true;
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
    if (!enabled || release == null || busy || checking || _disposed) return;
    busy = true;
    failed = false;
    progress = release.isAppStore ? null : 0;
    notifyListeners();
    try {
      final install = _install;
      if (release.isAppStore) {
        if (!await _openStore(release.url)) {
          throw StateError('Unable to open App Store');
        }
      } else if (install != null) {
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

Future<bool> _launchStore(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
