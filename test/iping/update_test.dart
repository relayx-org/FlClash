import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/iping/update.dart';
import 'package:fl_clash/iping/update_gate.dart';
import 'package:fl_clash/iping/update_provider.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';

final _current = PackageInfo(
  appName: 'iPing',
  packageName: 'my.iping.client',
  version: '1.0.0',
  buildNumber: '10',
);
final _release = IpingUpdate(
  version: '1.1.0',
  buildNumber: 11,
  url: Uri.parse('https://video.iping.my/releases/app.zip'),
  sha256: sha256.convert([1, 2, 3]).toString(),
  size: 3,
  format: 'zip',
);

class _Client extends IpingUpdateClient {
  Future<IpingUpdate?> Function() response = () async => _release;
  int calls = 0;

  @override
  Future<IpingUpdate?> check(String target, PackageInfo current) {
    calls++;
    return response();
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Map<String, Object> body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => mockPreferences({}));

  IpingUpdater makeUpdater(
    _Client client, {
    Future<void> Function()? onRequired,
    Future<void> Function(IpingUpdate, void Function(double))? install,
  }) {
    final updater = IpingUpdater(
      current: () => _current,
      target: Future.value('macos-arm64-zip'),
      client: client,
      enabled: true,
      onRequired: onRequired ?? () async {},
      beforeInstall: () async {},
      exitApplication: () async {},
      install: install ?? (_, _) async {},
    );
    addTearDown(updater.dispose);
    return updater;
  }

  test('selects the current architecture explicitly', () {
    expect(ipingUpdateArch(Abi.windowsArm64), 'arm64');
    expect(ipingUpdateArch(Abi.androidArm), 'arm');
    expect(ipingUpdateArch(Abi.linuxX64), 'amd64');
  });

  test('validates version, checksum, URL and same-version builds', () {
    final json = _release.toJson();
    expect(IpingUpdate.fromJson(json).isNewerThan(_current), isTrue);
    expect(
      IpingUpdate.fromJson({
        ...json,
        'version': '1.0.0',
        'buildNumber': 10,
      }).isNewerThan(_current),
      isFalse,
    );
    expect(
      IpingUpdate.fromJson({...json, 'version': '1.0.0'}).isNewerThan(_current),
      isTrue,
    );
    for (final invalid in [
      {...json, 'url': 'http://example.com/app.zip'},
      {...json, 'sha256': 'invalid'},
      {...json, 'size': 0},
      {...json, 'version': '1.1.0-pre.1'},
    ]) {
      expect(() => IpingUpdate.fromJson(invalid), throwsFormatException);
    }
  });

  test(
    'checks only the matching artifact and rejects a different package',
    () async {
      final manifest = <String, Object>{
        'schemaVersion': 1,
        'packageId': 'my.iping.client',
        'version': '1.1.0',
        'buildNumber': 11,
        'assets': {'macos-arm64-zip': _release.toJson()},
      };
      final dio = Dio()..httpClientAdapter = _Adapter(manifest);
      final client = IpingUpdateClient(dio: dio);
      addTearDown(client.close);
      expect(
        (await client.check('macos-arm64-zip', _current))?.version,
        '1.1.0',
      );
      await expectLater(
        client.check('windows-arm64-exe', _current),
        throwsFormatException,
      );
      dio.httpClientAdapter = _Adapter({
        ...manifest,
        'packageId': 'another.app',
      });
      await expectLater(
        client.check('macos-arm64-zip', _current),
        throwsFormatException,
      );
    },
  );

  test('rejects corrupt and truncated packages before installation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'iping-update-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/package.zip',
    ).writeAsBytes([1, 2, 3]);
    await verifyIpingUpdate(file.path, _release);
    await file.writeAsBytes([3, 2, 1]);
    await expectLater(
      verifyIpingUpdate(file.path, _release),
      throwsFormatException,
    );
    await file.writeAsBytes([1]);
    await expectLater(
      verifyIpingUpdate(file.path, _release),
      throwsFormatException,
    );
  });

  test(
    'coalesces checks and keeps mandatory state through network failures',
    () async {
      final client = _Client();
      final pending = Completer<IpingUpdate?>();
      client.response = () => pending.future;
      var stopped = 0;
      final updater = makeUpdater(client, onRequired: () async => stopped++);
      final first = updater.check();
      final second = updater.check();
      pending.complete(_release);
      await Future.wait([first, second]);
      expect(client.calls, 1);
      expect(stopped, 1);
      client.response = () async => throw const SocketException('offline');
      await updater.check();
      expect(updater.required, isTrue);
      expect(updater.failed, isTrue);
    },
  );

  test('restores a known required update while offline', () async {
    final first = makeUpdater(_Client());
    await first.initialize();
    final offline = _Client()
      ..response = () async => throw const SocketException('offline');
    final second = makeUpdater(offline);
    await second.initialize();
    expect(second.required, isTrue);
    expect(second.update!.buildNumber, 11);
  });

  test(
    'prevents concurrent installs and permits retry after a failure',
    () async {
      final pending = Completer<void>();
      var attempts = 0;
      final updater = makeUpdater(
        _Client(),
        install: (_, progress) async {
          attempts++;
          progress(0.5);
          if (attempts == 1) await pending.future;
        },
      );
      await updater.check();
      final first = updater.install();
      await updater.install();
      expect(attempts, 1);
      expect(updater.progress, 0.5);
      pending.completeError(StateError('download failed'));
      await first;
      expect(updater.busy, isFalse);
      expect(updater.failed, isTrue);
      expect(updater.required, isTrue);
      await updater.install();
      expect(attempts, 2);
      expect(updater.failed, isFalse);
    },
  );

  testWidgets(
    'blocks navigation and remains blocked after failed installation',
    (tester) async {
      final updater = makeUpdater(
        _Client(),
        install: (_, _) async => throw StateError('denied'),
      );
      await updater.check();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ipingUpdaterProvider.overrideWithValue(updater)],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              AppUiLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            builder: (context, child) =>
                wrapAppScopes(context, IpingUpdateGate(child: child!)),
            home: const Scaffold(body: Text('ACCOUNT')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT'), findsNothing);
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsNothing);
      unawaited(
        dialogs.showCommonDialog<String>(
          context: tester.element(find.byType(IpingRequiredUpdate)),
          child: const InputDialog(
            title: 'Administrator password',
            value: '',
            obscureText: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator password'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
