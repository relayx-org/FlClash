import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/iping/update.dart';
import 'package:fl_clash/iping/update_notice.dart';
import 'package:fl_clash/iping/update_widgets.dart';
import 'package:fl_clash/iping/update_provider.dart';
import 'package:fl_clash/ui/ui.dart';
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
final _storeRelease = IpingUpdate.fromJson({
  'version': '1.1.0',
  'buildNumber': 0,
  'url': 'https://apps.apple.com/app/id123456789',
  'sha256': '',
  'size': 0,
  'format': 'app-store',
});

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

class _BytesAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.value(Uint8List.fromList([1, 2, 3])),
      200,
      headers: {
        Headers.contentLengthHeader: ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnsendableListener {
  final port = RawReceivePort();
  final values = <double>[];
  void onProgress(double value) => values.add(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => mockPreferences({}));

  IpingUpdater makeUpdater(
    _Client client, {
    Future<void> Function(IpingUpdate, void Function(double))? install,
    Future<bool> Function(Uri)? openStore,
    Future<void> Function()? beforeInstall,
    Future<void> Function()? exitApplication,
    String target = 'macos-arm64-zip',
  }) {
    final updater = IpingUpdater(
      current: () => _current,
      target: Future.value(target),
      client: client,
      enabled: true,
      beforeInstall: beforeInstall ?? () async {},
      exitApplication: exitApplication ?? () async {},
      install: install ?? (_, _) async {},
      openStore: openStore,
    );
    addTearDown(updater.dispose);
    return updater;
  }

  test('selects the current architecture explicitly', () {
    expect(ipingUpdateArch(Abi.windowsArm64), 'arm64');
    expect(ipingUpdateArch(Abi.androidArm), 'arm');
    expect(ipingUpdateArch(Abi.linuxX64), 'amd64');
  });

  test('App Store metadata retains its installation route', () {
    final restored = IpingUpdate.fromJson(_storeRelease.toJson());
    expect(restored.isAppStore, isTrue);
    expect(restored.url, _storeRelease.url);
    expect(restored.isNewerThan(_current), isTrue);
    for (final invalid in [
      {..._storeRelease.toJson(), 'url': 'https://example.com/app/id123'},
      {..._storeRelease.toJson(), 'url': 'https://apps.apple.com/app/id0'},
      {..._storeRelease.toJson(), 'buildNumber': 11},
    ]) {
      expect(() => IpingUpdate.fromJson(invalid), throwsFormatException);
    }
  });

  test(
    'App Store installation opens the store and releases controls on failure',
    () async {
      var attempts = 0;
      final client = _Client()..response = () async => _storeRelease;
      final updater = makeUpdater(
        client,
        target: 'ios-app-store',
        openStore: (url) async {
          expect(url, _storeRelease.url);
          return ++attempts > 1;
        },
        install: (_, _) async =>
            fail('App Store updates must not install a package'),
        beforeInstall: () async =>
            fail('Opening the App Store must not prepare an app exit'),
        exitApplication: () async =>
            fail('Opening the App Store must not exit iPing'),
      );
      await updater.check();
      await updater.install();
      expect(updater.failed, isTrue);
      expect(updater.busy, isFalse);
      expect(updater.progress, isNull);
      await updater.install();
      expect(updater.failed, isFalse);
      expect(updater.busy, isFalse);
      expect(updater.update, isNotNull);
      expect(attempts, 2);
    },
  );

  test('an offline check offers no cached App Store requirement', () async {
    final first = makeUpdater(
      _Client()..response = () async => _storeRelease,
      target: 'ios-app-store',
    );
    await first.check();
    final offline = _Client()
      ..response = () async => throw const SocketException('offline');
    final restored = makeUpdater(offline, target: 'ios-app-store');
    await restored.check();
    expect(restored.update, isNull);
    expect(restored.checkFailed, isTrue);
    final installed = IpingUpdater(
      current: () => PackageInfo(
        appName: 'iPing',
        packageName: 'my.iping.client',
        version: '1.1.0',
        buildNumber: '20',
      ),
      target: Future.value('ios-app-store'),
      client: _Client()..response = () async => null,
      enabled: true,
      beforeInstall: () async {},
      exitApplication: () async {},
    );
    addTearDown(installed.dispose);
    await installed.check();
    expect(installed.update, isNull);
  });

  test('disposing during an App Store launch ignores its completion', () async {
    final pending = Completer<bool>();
    final updater = IpingUpdater(
      current: () => _current,
      target: Future.value('ios-app-store'),
      client: _Client()..response = () async => _storeRelease,
      enabled: true,
      openStore: (_) => pending.future,
      beforeInstall: () async {},
      exitApplication: () async {},
    );
    await updater.check();
    final launching = updater.install();
    updater.dispose();
    pending.complete(true);
    await launching;
  });

  testWidgets(
    'App Store updates show store-specific feedback without download percentages',
    (tester) async {
      final pending = Completer<bool>();
      final updater = makeUpdater(
        _Client()..response = () async => _storeRelease,
        target: 'ios-app-store',
        openStore: (_) => pending.future,
      );
      await updater.check();
      await tester.pumpWidget(
        TestApp(
          overrides: [ipingUpdaterProvider.overrideWithValue(updater)],
          child: const Scaffold(body: IpingCheckUpdateItem()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('Update in App Store'), findsOneWidget);
      expect(
        find.text('Install the update in the App Store, then reopen iPing.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Update in App Store'));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(IpingUpdateDialog),
          matching: find.byType(CommonCircleLoading),
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('0%'), findsNothing);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to open the App Store. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

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
    'verifies a download whose progress listener cannot cross isolates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'iping-update-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final client = IpingUpdateClient(
        dio: Dio()..httpClientAdapter = _BytesAdapter(),
        temporaryDirectory: () async => directory,
      );
      addTearDown(client.close);
      final listener = _UnsendableListener();
      addTearDown(listener.port.close);
      final file = await client.download(_release, listener.onProgress);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(listener.values.last, 1);
    },
  );

  test(
    'coalesces checks without preparing an installation or stopping the app',
    () async {
      final client = _Client();
      final pending = Completer<IpingUpdate?>();
      client.response = () => pending.future;
      var preparations = 0;
      final updater = makeUpdater(
        client,
        beforeInstall: () async => preparations++,
      );
      expect(client.calls, 0);
      final first = updater.check();
      final second = updater.check();
      expect(updater.checking, isTrue);
      pending.complete(_release);
      await Future.wait([first, second]);
      expect(client.calls, 1);
      expect(preparations, 0);
      expect(updater.update, _release);
      expect(updater.checking, isFalse);
      client.response = () async => throw const SocketException('offline');
      await updater.check();
      expect(updater.update, _release);
      expect(updater.checkFailed, isTrue);
      expect(updater.failed, isFalse);
      expect(preparations, 0);
      client.response = () async => null;
      await updater.check();
      expect(updater.update, isNull);
      expect(updater.checkFailed, isFalse);
    },
  );

  test('old mandatory update metadata is ignored', () async {
    await mockPreferences({
      'iping.requiredUpdate:$ipingUpdateBase:macos-arm64-zip': jsonEncode(
        _release.toJson(),
      ),
    });
    final client = _Client()
      ..response = () async => throw const SocketException('offline');
    final updater = makeUpdater(client);
    expect(updater.update, isNull);
    expect(client.calls, 0);
    await updater.check();
    expect(updater.update, isNull);
    expect(updater.checkFailed, isTrue);
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
      expect(updater.update, isNotNull);
      await updater.install();
      expect(attempts, 2);
      expect(updater.failed, isFalse);
    },
  );

  Future<void> pumpUpdates(WidgetTester tester, IpingUpdater updater) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [ipingUpdaterProvider.overrideWithValue(updater)],
        child: IpingUpdateNotice(
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  const Text('ACCOUNT'),
                  const IpingCheckUpdateItem(),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('NEXT')),
                      ),
                    ),
                    child: const Text('CONTINUE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'background notices can be postponed and do not replace navigation',
    (tester) async {
      final client = _Client();
      final updater = makeUpdater(client);
      await pumpUpdates(tester, updater);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('New version found'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(client.calls, 2);
      expect(find.byType(IpingUpdateDialog), findsNothing);
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.byType(IpingUpdateDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(IpingUpdateDialog), findsNothing);
      client.response = () async => IpingUpdate.fromJson({
        ..._release.toJson(),
        'version': '1.2.0',
        'buildNumber': 12,
      });
      await tester.pump(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(find.byType(IpingUpdateDialog), findsOneWidget);
      expect(find.textContaining('Version 1.2.0 is available'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('NEXT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed installations can be dismissed and retried manually', (
    tester,
  ) async {
    final updater = makeUpdater(
      _Client(),
      install: (_, _) async => throw StateError('denied'),
    );
    await pumpUpdates(tester, updater);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Download manually'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.byType(IpingUpdateDialog), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an update download can continue after closing its dialog', (
    tester,
  ) async {
    final pending = Completer<void>();
    final updater = makeUpdater(_Client(), install: (_, _) => pending.future);
    await pumpUpdates(tester, updater);
    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(updater.busy, isTrue);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(IpingUpdateDialog), findsNothing);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(updater.busy, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'manual checks distinguish the latest version from network errors',
    (tester) async {
      final client = _Client()..response = () async => null;
      final updater = makeUpdater(client);
      await pumpUpdates(tester, updater);
      expect(find.byType(CommonDialog), findsNothing);
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('The app is already up to date'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      client.response = () async => throw const SocketException('offline');
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Unable to check for updates. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('The app is already up to date'), findsNothing);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final pending = Completer<IpingUpdate?>();
      client.response = () => pending.future;
      await tester.tap(find.text('Check for updates'));
      await tester.pump();
      expect(find.byType(CommonCircleLoading), findsOneWidget);
      expect(tester.widget<ListItem>(find.byType(ListItem)).onTap, isNull);
      pending.complete(_release);
      await tester.pumpAndSettle();
      expect(find.byType(IpingUpdateDialog), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
