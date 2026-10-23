import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeIpingApi api;
  late MemorySessionStorage storage;
  late MemoryProfileStorage profiles;
  late IpingSession session;

  setUp(() {
    api = FakeIpingApi();
    storage = MemorySessionStorage();
    profiles = MemoryProfileStorage();
    session = IpingSession(
      api: api,
      authenticate: api.authenticate,
      cancelAuthentication: () {},
      storage: storage,
      profiles: profiles,
      onChanged: (_) {},
    );
  });
  tearDown(() => session.dispose());

  Future<void> signIn() => session.signIn();

  test(
    'startup without credentials stops and removes orphaned configuration',
    () async {
      profiles.value = (nodes: 2, updated: DateTime(2026));
      await session.initialize();
      expect(profiles.stops, 1);
      expect(profiles.value, isNull);
      expect(session.state.canConnect, isFalse);
    },
  );

  test(
    'secure storage failures stop the connection and keep its gate closed',
    () async {
      await signIn();
      storage.readFails = true;
      await session.initialize();
      expect(profiles.stops, 1);
      expect(session.state.canConnect, isFalse);
      expect(session.state.failure, IpingFailure.storage);
    },
  );

  test(
    'empty subscriptions close the gate even if stopping VPN fails',
    () async {
      await signIn();
      api.nodes = 0;
      profiles.stopFails = true;
      await session.synchronize();
      expect(session.state.canConnect, isFalse);
      expect(session.state.failure, IpingFailure.storage);
    },
  );

  test(
    'logout removes configuration even if deleting credentials fails',
    () async {
      await signIn();
      storage.clearFails = true;
      await session.signOut();
      expect(profiles.value, isNull);
      expect(session.state.account, isNull);
      expect(session.state.canConnect, isFalse);
      expect(session.state.failure, IpingFailure.storage);
    },
  );

  test(
    'sign in persists the session and loads its subscription without starting VPN',
    () async {
      await signIn();
      expect(session.state.account?.id, 7);
      expect(session.state.canConnect, isTrue);
      expect(session.state.busy, isFalse);
      expect(storage.value?.subscriptionToken, 'subscription');
      expect(storage.value?.apiKey, '62ab74aa-0473-4790-9bd5-2f728dd42c56');
      expect(profiles.saves, 1);
      expect(profiles.stops, 0);
    },
  );

  test(
    'restart restores the saved subscription without identity-provider calls',
    () async {
      await signIn();
      await session.initialize();
      expect(profiles.saves, 2);
      expect(session.state.canConnect, isTrue);
      expect(
        session.state.account?.apiKey,
        '62ab74aa-0473-4790-9bd5-2f728dd42c56',
      );
    },
  );

  test(
    'revoked subscription credentials clear account and configuration',
    () async {
      await signIn();
      api.subscriptionFailure = IpingFailure.session;
      await session.synchronize();
      expect(session.state.account, isNull);
      expect(session.state.failure, IpingFailure.session);
      expect(storage.value, isNull);
      expect(profiles.value, isNull);
      expect(profiles.stops, 1);
    },
  );

  test('service outages preserve the cached subscription on restart', () async {
    await signIn();
    api.subscriptionFailure = IpingFailure.unavailable;
    await session.initialize();
    expect(session.state.canConnect, isTrue);
    expect(session.state.failure, IpingFailure.unavailable);
  });

  test('failed downloads preserve the last successful subscription', () async {
    await signIn();
    final previous = profiles.value;
    api.subscriptionFailure = IpingFailure.subscription;
    await session.synchronize();
    expect(profiles.value, previous);
    expect(profiles.saves, 1);
    expect(session.state.canConnect, isTrue);
  });

  test('empty subscriptions stop VPN and disable connection', () async {
    await signIn();
    api.nodes = 0;
    await session.synchronize();
    expect(profiles.stops, 1);
    expect(session.state.canConnect, isFalse);
    expect(session.state.account, isNotNull);
    expect(session.state.failure, isNull);
  });

  test('concurrent refresh requests share a single download', () async {
    await signIn();
    api.download = Completer();
    final first = session.synchronize();
    final second = session.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(api.downloads, 2);
    api.download!.complete((bytes: Uint8List(0), nodes: 3));
    await Future.wait([first, second]);
    expect(profiles.saves, 2);
    expect(session.state.nodes, 3);
  });

  test('logout prevents an old download from restoring account data', () async {
    await signIn();
    api.download = Completer();
    final pending = session.synchronize();
    await Future<void>.delayed(Duration.zero);
    await session.signOut();
    api.download!.complete((bytes: Uint8List(0), nodes: 4));
    await pending;
    expect(storage.value, isNull);
    expect(profiles.value, isNull);
    expect(session.state.account, isNull);
    expect(session.state.nodes, 0);
  });

  test(
    'logout waits for an existing profile write before clearing it',
    () async {
      await signIn();
      profiles.pendingSave = Completer();
      final pending = session.synchronize();
      await Future<void>.delayed(Duration.zero);
      final logout = session.signOut();
      profiles.pendingSave!.complete();
      await Future.wait([pending, logout]);
      expect(profiles.value, isNull);
      expect(storage.value, isNull);
      expect(session.state.canConnect, isFalse);
    },
  );

  test('local credentials are cleared even when VPN shutdown fails', () async {
    await signIn();
    profiles.stopFails = true;
    await session.signOut();
    expect(storage.value, isNull);
    expect(profiles.value, isNull);
    expect(session.state.failure, IpingFailure.storage);
  });

  test(
    'switching accounts clears the previous account configuration',
    () async {
      await signIn();
      await session.signOut();
      api.userId = 8;
      await signIn();
      expect(session.state.account?.id, 8);
      expect(storage.value?.id, 8);
      expect(profiles.saves, 2);
      expect(profiles.stops, 1);
    },
  );
}
