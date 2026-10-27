import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/app_paths.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Setup extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async => true;

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    requests.add(running);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late db.Database previousDatabase;
  late Directory root;
  late _Core core;
  late _Setup setup;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('iping-storage-');
    await useAppPaths(root);
    previousDatabase = db.database;
    db.database = db.Database(NativeDatabase.memory());
    core = _Core();
    setup = _Setup();
    when(() => core.validateConfig(any())).thenAnswer((_) async => '');
    when(() => core.convertProxies(any())).thenAnswer((_) async => []);
    when(() => core.clearEffect(any())).thenAnswer((_) async => '');
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(() => setup),
      ],
    );
    container.listen(profilesProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    await container.read(profilesStreamProvider.future);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    container.dispose();
    await db.database.close();
    db.database = previousDatabase;
    root.deleteSync(recursive: true);
  });

  IpingSubscription subscription(String name) => (
    bytes: Uint8List.fromList(
      utf8.encode(
        'proxies:\n  - {name: $name, type: ss, server: example.com, port: 443}\n',
      ),
    ),
    nodes: 1,
  );

  test(
    'automatic sync updates one persisted profile and logout removes its file',
    () async {
      final profiles = container.read(ipingProfilesProvider);
      expect(await profiles.read(), isNull);
      await profiles.save(
        'https://example.com/sub?token=first',
        subscription('A'),
      );
      final first = container.read(profilesProvider).single;
      expect(first.autoUpdate, isFalse);
      expect(container.read(currentProfileIdProvider), first.id);
      await profiles.save(
        'https://example.com/sub?token=rotated',
        subscription('B'),
      );
      final saved = container.read(profilesProvider).single;
      expect(saved.id, first.id);
      expect(saved.url, endsWith('token=rotated'));
      expect(await db.database.profilesDao.query().get(), hasLength(1));
      expect((await profiles.read())?.nodes, 1);
      final file = await saved.file;
      expect(await file.readAsString(), contains('name: B'));
      expect(setup.requests, isEmpty);
      await profiles.stop();
      await profiles.clear();
      expect(setup.requests, [false]);
      expect(container.read(profilesProvider), isEmpty);
      expect(await db.database.profilesDao.query().get(), isEmpty);
      expect(await file.exists(), isFalse);
      expect(container.read(currentProfileIdProvider), isNull);
    },
  );

  test(
    'core rejection preserves the previous profile bytes and selection',
    () async {
      final profiles = container.read(ipingProfilesProvider);
      await profiles.save('https://example.com/sub', subscription('A'));
      final saved = container.read(profilesProvider).single;
      final file = await saved.file;
      final bytes = await file.readAsBytes();
      when(
        () => core.validateConfig(any()),
      ).thenAnswer((_) async => 'Invalid node');
      await expectLater(
        profiles.save('https://example.com/new', subscription('B')),
        throwsException,
      );
      expect(await file.readAsBytes(), bytes);
      expect(container.read(currentProfileIdProvider), saved.id);
      expect(container.read(profilesProvider).single.url, saved.url);
    },
  );

  test(
    'session secure storage round-trips and rejects malformed saved data',
    () async {
      final storage = container.read(ipingStorageProvider);
      const account = IpingAccount(
        subscriptionToken: 'subscription',
        apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
        id: 7,
        email: 'user@example.com',
      );
      await storage.write(const IpingStoredSession(account: account));
      expect(
        (await storage.read())?.account?.subscriptionToken,
        'subscription',
      );
      expect((await storage.read())?.account?.apiKey, account.apiKey);
      await storage.clear();
      expect(await storage.read(), isNull);
      FlutterSecureStorage.setMockInitialValues({
        'my.iping.client.subscription': 'malformed',
      });
      expect(await storage.read(), isNull);
    },
  );

  test('legacy saved subscriptions stay usable without an API key', () async {
    FlutterSecureStorage.setMockInitialValues({
      'my.iping.client.subscription': jsonEncode({
        'id': 7,
        'email': 'user@example.com',
        'subscription_token': 'legacy-subscription',
      }),
    });
    final account = await container.read(ipingStorageProvider).read();
    expect(account?.account?.subscriptionToken, 'legacy-subscription');
    expect(account?.account?.apiKey, isNull);
  });

  test('manual subscription links round-trip through secure storage', () async {
    const url = 'https://example.com/sub?token=secret';
    final storage = container.read(ipingStorageProvider);
    await storage.write(const IpingStoredSession(manualUrl: url));
    final saved = await storage.read();
    expect(saved?.account, isNull);
    expect(saved?.manualUrl, url);
    FlutterSecureStorage.setMockInitialValues({
      'my.iping.client.subscription': '{"subscription_url":"file:///tmp/sub"}',
    });
    expect(await storage.read(), isNull);
  });

  test('invalid API credentials invalidate the saved secure session', () async {
    FlutterSecureStorage.setMockInitialValues({
      'my.iping.client.subscription': jsonEncode({
        'id': 7,
        'email': 'user@example.com',
        'subscription_token': 'subscription',
        'api_key': 'invalid\r\nheader',
      }),
    });
    expect(await container.read(ipingStorageProvider).read(), isNull);
    expect(
      await const FlutterSecureStorage().read(
        key: 'my.iping.client.subscription',
      ),
      isNull,
    );
  });
}
