import 'dart:async';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeIpingApi api;
  late ProviderContainer container;

  ProviderContainer createContainer(FakeIpingApi api) => ProviderContainer(
    overrides: [
      ipingApiProvider.overrideWithValue(api),
      ipingStorageProvider.overrideWithValue(MemorySessionStorage()),
      ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
    ],
  );

  Future<void> refresh() =>
      container.read(ipingSiteConfigProvider.notifier).refresh();

  Future<void> storeAccount() => container
      .read(ipingStorageProvider)
      .write(
        const IpingAccount(
          id: 7,
          email: 'user@example.com',
          subscriptionToken: 'subscription',
        ),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeIpingApi();
    container = createContainer(api);
  });

  tearDown(() => container.dispose());

  test('missing or incorrectly typed fields keep usable local defaults', () {
    final config = IpingSiteConfig.fromJson({
      'SITE_NAME': '  ',
      'SITE_DESCRIPTION': 3,
      'LOGO_URL': null,
      'ALLOW_REGISTER': 'false',
    }, site: api.site);

    expect(config.name, 'iPing');
    expect(config.description, isEmpty);
    expect(config.logoUrl, isEmpty);
    expect(config.allowRegister, isTrue);
  });

  test(
    'logo URLs resolve against the configured site and reject non-web URLs',
    () {
      for (final entry in {
        '/logo.svg': '${api.site}/logo.svg',
        'logo.png': '${api.site}/logo.png',
        'https://cdn.example.com/logo.webp':
            'https://cdn.example.com/logo.webp',
        'javascript:alert(1)': '',
        'file:///tmp/logo.png': '',
      }.entries) {
        final config = IpingSiteConfig.fromJson({
          'LOGO_URL': entry.key,
        }, site: api.site);

        expect(config.logoUrl, entry.value);
      }
    },
  );

  test(
    'startup uses cached settings while the network refresh is pending',
    () async {
      api.siteSettings = const IpingSiteConfig(
        name: 'Cached site',
        description: 'Cached introduction',
        allowRegister: false,
      );
      await refresh();
      container.dispose();
      container = createContainer(api);
      final request = api.siteRequest = Completer<IpingSiteConfig>();

      final pending = refresh();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ipingSiteConfigProvider).name, 'Cached site');
      expect(container.read(ipingSiteConfigProvider).allowRegister, isFalse);
      request.complete(const IpingSiteConfig(name: 'Updated site'));
      await pending;
      expect(container.read(ipingSiteConfigProvider).name, 'Updated site');
    },
  );

  test(
    'an unavailable endpoint preserves cached settings across restarts',
    () async {
      api.siteSettings = const IpingSiteConfig(name: 'Offline site');
      await refresh();
      container.dispose();
      api.siteFails = true;
      container = createContainer(api);

      await refresh();

      expect(container.read(ipingSiteConfigProvider).name, 'Offline site');
    },
  );

  test('another site never receives the previous site cache', () async {
    api.siteSettings = const IpingSiteConfig(name: 'First site');
    await refresh();
    container.dispose();
    final other = FakeIpingApi(site: 'https://other.example.com')
      ..siteFails = true;
    container = createContainer(other);

    await refresh();

    expect(container.read(ipingSiteConfigProvider).name, 'iPing');
    expect(other.siteRequests, 1);
  });

  test('a corrupt cache does not prevent fetching public settings', () async {
    final store = await SharedPreferences.getInstance();
    await store.setString('my.iping.client.site:${api.site}', 'broken JSON');
    api.siteSettings = const IpingSiteConfig(name: 'Recovered site');

    await refresh();

    expect(container.read(ipingSiteConfigProvider).name, 'Recovered site');
  });

  test(
    'concurrent refreshes share one request and keep defaults usable',
    () async {
      final request = api.siteRequest = Completer<IpingSiteConfig>();
      final first = refresh();
      final second = refresh();
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(api.siteRequests, 1);
      expect(container.read(ipingSiteConfigProvider).allowRegister, isTrue);
      request.complete(const IpingSiteConfig(name: 'Shared result'));
      await Future.wait([first, second]);
      expect(container.read(ipingSiteConfigProvider).name, 'Shared result');
    },
  );

  test(
    'manual sync updates subscriptions without waiting for public settings',
    () async {
      final session = container.read(ipingSessionProvider.notifier);
      await storeAccount();
      await session.controller.initialize();
      final account = container.read(ipingSessionProvider).account;
      final request = api.siteRequest = Completer<IpingSiteConfig>();

      await session.synchronize();

      expect(api.downloads, 2);
      expect(container.read(ipingSessionProvider).account, same(account));
      request.completeError(StateError('site unavailable'));
      await refresh();
      expect(container.read(ipingSessionProvider).canConnect, isTrue);
      expect(container.read(ipingSessionProvider).failure, isNull);
    },
  );

  test('sign-out preserves public configuration for the next login', () async {
    api.siteSettings = const IpingSiteConfig(name: 'Public brand');
    await refresh();
    final session = container.read(ipingSessionProvider.notifier).controller;
    await storeAccount();
    await session.initialize();
    await session.signOut();
    container.dispose();
    api.siteFails = true;
    container = createContainer(api);

    await refresh();

    expect(container.read(ipingSiteConfigProvider).name, 'Public brand');
    expect(container.read(ipingSessionProvider).account, isNull);
  });

  test(
    'an old request cannot overwrite settings after provider invalidation',
    () async {
      final request = api.siteRequest = Completer<IpingSiteConfig>();
      final previous = refresh();
      await Future<void>.delayed(Duration.zero);
      container.invalidate(ipingSiteConfigProvider);
      api.siteRequest = null;
      api.siteSettings = const IpingSiteConfig(name: 'Current brand');
      await refresh();

      request.complete(const IpingSiteConfig(name: 'Stale brand'));
      await previous;

      expect(container.read(ipingSiteConfigProvider).name, 'Current brand');
    },
  );
}
