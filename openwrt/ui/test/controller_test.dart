import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:iping_openwrt/backend.dart';
import 'package:iping_openwrt/controller.dart';

import 'fake_client.dart';

class _Backend extends RouterBackend {
  _Backend(super.client);

  Completer<IpingTelemetry>? pending;

  @override
  Future<IpingTelemetry> readTelemetry() =>
      pending?.future ??
      Future.value(const IpingTelemetry(connections: 7, mode: Mode.direct));
}

void main() {
  setUpAll(() => AppLocalizations.load(const Locale('en')));

  test('signed-out state avoids authenticated telemetry requests', () async {
    final client = FakeRouterClient(signedIn: false)..fail = true;
    final controller = RouterController(client);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(client.calls, ['status']);
    expect(controller.error, isNull);
  });

  test(
    'manual import enables telemetry and probes without an account',
    () async {
      final client = FakeRouterClient(signedIn: false)..running = false;
      final controller = RouterController(client);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(
        await controller.importSubscription('  https://example.com/sub  '),
        isTrue,
      );
      expect(controller.status.hasSubscription, isTrue);
      expect(controller.signedIn, isFalse);
      expect(controller.connected, isFalse);
      expect(client.subscriptionUrl, 'https://example.com/sub');
      expect(
        client.calls,
        containsAll(['import_subscription', 'telemetry', 'probe_route']),
      );
      expect(client.calls, isNot(contains('account')));
      expect(await controller.setConnected(true), isTrue);
      expect(await controller.testDelay('Node A'), 42);
      await controller.synchronize();
      expect(client.calls, contains('sync'));
    },
  );

  test(
    'failed manual import preserves the previous source and releases controls',
    () async {
      final client = FakeRouterClient(signedIn: false)
        ..manualSubscription = true
        ..subscriptionUrl = 'https://example.com/old';
      final controller = RouterController(client);
      addTearDown(controller.dispose);
      await controller.initialize();
      client.failImport = true;
      expect(
        await controller.importSubscription('https://example.com/new'),
        isFalse,
      );
      expect(client.subscriptionUrl, 'https://example.com/old');
      expect(controller.status.hasSubscription, isTrue);
      expect(controller.busy, isFalse);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'dashboard reads typed telemetry through the injected backend',
    () async {
      final client = FakeRouterClient();
      final controller = RouterController(client, backend: _Backend(client));
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.telemetry.connections, 7);
      expect(controller.telemetry.mode, Mode.direct);
      expect(client.calls, isNot(contains('telemetry')));
    },
  );

  test('a disposed dashboard ignores a pending telemetry result', () async {
    final client = FakeRouterClient();
    final backend = _Backend(client)..pending = Completer<IpingTelemetry>();
    final controller = RouterController(client, backend: backend);
    final refreshing = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    backend.pending!.complete(const IpingTelemetry(connections: 9));
    await refreshing;
    expect(controller.telemetry.connections, 0);
  });

  test(
    'offline mode updates and failed changes release the interaction',
    () async {
      final client = FakeRouterClient()..running = false;
      final controller = RouterController(client);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.setMode(Mode.global);
      expect(controller.telemetry.mode, Mode.global);
      expect(controller.pending, isFalse);
      client.fail = true;
      await controller.setMode(Mode.direct);
      expect(client.mode, 'global');
      expect(controller.pending, isFalse);
      expect(controller.error, isNotNull);
    },
  );
  test('browser login loads the account without starting the router', () async {
    final client = FakeRouterClient(signedIn: false)..running = false;
    final controller = RouterController(client);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.signIn();
    expect(controller.signedIn, isTrue);
    expect(controller.connected, isFalse);
    expect(controller.account?.balance, 128.5);
    expect(client.calls, isNot(contains('connect')));
  });

  test('canceling browser sign-in releases the pending interaction', () async {
    final client = FakeRouterClient(signedIn: false)..login = Completer<void>();
    final controller = RouterController(client);
    addTearDown(controller.dispose);
    await controller.initialize();
    final signingIn = controller.signIn();
    expect(controller.authorizing, isTrue);
    controller.cancelSignIn();
    await signingIn;
    expect(controller.busy, isFalse);
    expect(controller.signedIn, isFalse);
    expect(client.calls, isNot(contains('account')));
  });

  test(
    'a failed operation and delay test both release their controls',
    () async {
      final client = FakeRouterClient();
      final controller = RouterController(client);
      addTearDown(controller.dispose);
      await controller.initialize();
      client.fail = true;
      await controller.setConnected(false);
      expect(controller.pending, isFalse);
      expect(controller.error, isNotNull);
      expect(await controller.testDelay('Node A'), isNull);
      expect(controller.testing, isEmpty);
      expect(controller.delays, isEmpty);
    },
  );
}
