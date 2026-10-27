import 'dart:async';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/controller.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backend extends Mock implements IpingBackend {}

const _signedIn = IpingBackendState(
  signedIn: true,
  connected: true,
  email: 'one@example.com',
);
const _user = IpingUserInfo(
  id: 1,
  email: 'one@example.com',
  balance: 10,
  status: 'active',
);
const _url = 'https://delay.test/204';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Backend backend;
  late IpingController controller;
  late IpingBackendState state;

  setUp(() {
    backend = _Backend();
    state = _signedIn;
    when(backend.readState).thenAnswer((_) async => state);
    when(backend.readTelemetry).thenAnswer((_) async => const IpingTelemetry());
    when(
      backend.readSiteConfig,
    ).thenAnswer((_) async => const IpingSiteConfig());
    when(backend.readAccount).thenAnswer((_) async => _user);
    when(backend.cancelSignIn).thenReturn(null);
    when(backend.synchronize).thenAnswer((_) async {});
    when(backend.signOut).thenAnswer((_) async {
      state = const IpingBackendState();
    });
    when(() => backend.setConnected(any())).thenAnswer((_) async => true);
    controller = IpingController(backend, delayConcurrency: 2);
  });
  tearDown(() => controller.dispose());

  test(
    'manual imports refresh proxy metadata even when node counts are unchanged',
    () async {
      when(
        () => backend.importSubscription(any()),
      ).thenAnswer((_) async => true);
      await controller.initialize();
      final revision = controller.revision;
      expect(
        await controller.importSubscription('https://example.com/sub'),
        isTrue,
      );
      expect(controller.revision, greaterThan(revision));
      expect(controller.pending, isFalse);
    },
  );

  test(
    'manual subscriptions poll telemetry and keep delay tests alive',
    () async {
      state = const IpingBackendState(
        manualSubscription: true,
        connected: true,
      );
      when(backend.readTelemetry).thenAnswer(
        (_) async => const IpingTelemetry(connections: 3, mode: Mode.global),
      );
      final delay = Completer<Delay?>();
      when(
        () => backend.testDelay('Node', url: _url),
      ).thenAnswer((_) => delay.future);
      await controller.initialize();
      expect(controller.signedIn, isFalse);
      expect(controller.telemetry.connections, 3);
      expect(controller.telemetry.mode, Mode.global);
      final pending = controller.testDelay('Node', url: _url);
      await _settle();
      controller.receiveState(state);
      expect(controller.isTestingDelay('Node', _url), isTrue);
      delay.complete(const Delay(name: 'Node', url: _url, value: 42));
      expect(await pending, 42);
      verifyNever(backend.readAccount);
    },
  );

  test('telemetry polling preserves proxy metadata until it changes', () async {
    await controller.initialize();
    final revision = controller.revision;
    await controller.refresh();
    expect(controller.revision, revision);
    await controller.synchronize();
    expect(controller.revision, greaterThan(revision));
  });

  test('concurrent refreshes share one authoritative read', () async {
    final result = Completer<IpingBackendState>();
    when(backend.readState).thenAnswer((_) => result.future);
    final first = controller.refresh();
    final second = controller.refresh();
    result.complete(_signedIn);
    await Future.wait([first, second]);
    verify(backend.readState).called(1);
    verify(backend.readTelemetry).called(1);
    expect(controller.signedIn, isTrue);
  });

  test('an old telemetry read cannot restore a signed-out session', () async {
    final telemetry = Completer<IpingTelemetry>();
    when(backend.readTelemetry).thenAnswer((_) => telemetry.future);
    final refreshing = controller.refresh();
    await _settle();
    final signingOut = controller.signOut();
    telemetry.complete(const IpingTelemetry(connections: 9));
    await Future.wait([refreshing, signingOut]);
    expect(controller.signedIn, isFalse);
    expect(controller.telemetry.connections, 0);
    expect(controller.pending, isFalse);
  });

  test('sync is single flight and a failed sync can be retried', () async {
    final result = Completer<void>();
    when(backend.synchronize).thenAnswer((_) => result.future);
    final first = controller.synchronize();
    final second = controller.synchronize();
    expect(controller.busy, isTrue);
    result.completeError(StateError('offline'));
    await Future.wait([first, second]);
    verify(backend.synchronize).called(1);
    expect(controller.pending, isFalse);
    expect(controller.error, contains('offline'));
    when(backend.synchronize).thenAnswer((_) async {});
    await controller.synchronize();
    expect(controller.error, isNull);
  });

  test(
    'connection intents reach the platform without waiting for an old one',
    () async {
      final start = Completer<bool>();
      final stop = Completer<bool>();
      when(() => backend.setConnected(true)).thenAnswer((_) => start.future);
      when(() => backend.setConnected(false)).thenAnswer((_) => stop.future);
      final starting = controller.setConnected(true);
      final stopping = controller.setConnected(false);
      verifyInOrder([
        () => backend.setConnected(true),
        () => backend.setConnected(false),
      ]);
      state = const IpingBackendState(signedIn: true);
      stop.complete(true);
      await stopping;
      expect(controller.connected, isFalse);
      start.completeError(StateError('superseded start'));
      expect(await starting, isFalse);
      expect(controller.connected, isFalse);
      expect(controller.error, isNull);
      expect(controller.busy, isFalse);
    },
  );

  test('cancelled sign-in cannot overwrite a subsequent sign-in', () async {
    state = const IpingBackendState();
    final old = Completer<void>();
    when(() => backend.signIn(register: false)).thenAnswer((_) => old.future);
    final first = controller.signIn();
    controller.cancelSignIn();
    when(() => backend.signIn(register: true)).thenAnswer((_) async {
      state = _signedIn;
    });
    await controller.signIn(register: true);
    expect(controller.authorizing, isFalse);
    expect(controller.account?.id, 1);
    old.completeError(StateError('cancelled'));
    await first;
    expect(controller.error, isNull);
    expect(controller.signedIn, isTrue);
    expect(controller.busy, isFalse);
  });

  test(
    'a late account read cannot repopulate the account after logout',
    () async {
      await controller.refresh();
      final result = Completer<IpingUserInfo?>();
      when(backend.readAccount).thenAnswer((_) => result.future);
      final reading = controller.refreshAccount();
      await controller.signOut();
      result.complete(_user);
      await reading;
      expect(controller.account, isNull);
      expect(controller.signedIn, isFalse);
    },
  );

  test('failed settings propagate and release the pending operation', () async {
    when(
      () => backend.updateSettings(any()),
    ).thenThrow(StateError('save failed'));
    await expectLater(
      controller.saveSettings({'allow-lan': true}),
      throwsStateError,
    );
    expect(controller.pending, isFalse);
    expect(controller.error, contains('save failed'));
  });

  test(
    'delay requests coalesce by URL and update each result as it arrives',
    () async {
      final answers = <(String, String), Completer<Delay?>>{};
      when(() => backend.testDelay(any(), url: any(named: 'url'))).thenAnswer((
        call,
      ) {
        final name = call.positionalArguments.single as String;
        final url = call.namedArguments[#url] as String;
        return answers.putIfAbsent((name, url), Completer<Delay?>.new).future;
      });
      final a = controller.testDelay('A', url: _url);
      final duplicate = controller.testDelay('A', url: _url);
      final b = controller.testDelay('A', url: 'https://other.test');
      expect(answers, hasLength(2));
      answers[('A', _url)]!.complete(
        const Delay(name: 'A', url: _url, value: 12),
      );
      expect(await a, 12);
      expect(await duplicate, 12);
      expect(controller.delayFor('A', _url), 12);
      expect(controller.isTestingDelay('A', _url), isFalse);
      expect(controller.testing, contains('A'));
      answers[('A', 'https://other.test')]!.complete(
        const Delay(name: 'A', url: 'https://other.test', value: 34),
      );
      expect(await b, 34);
      expect(controller.delayFor('A', _url), 12);
      expect(controller.delayFor('A', 'https://other.test'), 34);
      expect(controller.testing, isEmpty);
    },
  );

  test('a batch bounds concurrency and advances queued nodes', () async {
    final answers = <String, Completer<Delay?>>{};
    when(() => backend.testDelay(any(), url: _url)).thenAnswer((call) {
      final name = call.positionalArguments.single as String;
      return answers.putIfAbsent(name, Completer<Delay?>.new).future;
    });
    final run = controller.testDelays(['A', 'B', 'C'], url: _url);
    expect(answers.keys, ['A', 'B']);
    expect(controller.isRunningDelay('A', _url), isTrue);
    expect(controller.isTestingDelay('C', _url), isTrue);
    expect(controller.isRunningDelay('C', _url), isFalse);
    answers['A']!.complete(const Delay(name: 'A', url: _url, value: 5));
    await _settle();
    expect(controller.isTestingDelay('A', _url), isFalse);
    expect(controller.isRunningDelay('C', _url), isTrue);
    answers['B']!.complete(const Delay(name: 'B', url: _url, value: -1));
    answers['C']!.complete(const Delay(name: 'C', url: _url, value: -2));
    expect(await run, isTrue);
    expect(controller.testing, isEmpty);
  });

  test(
    'disconnect resolves cancelled delays and ignores late results',
    () async {
      await controller.refresh();
      final answer = Completer<Delay?>();
      when(
        () => backend.testDelay(any(), url: _url),
      ).thenAnswer((_) => answer.future);
      final run = controller.testDelays(['A', 'B', 'C'], url: _url);
      state = const IpingBackendState(signedIn: true);
      await controller.refresh();
      expect(await run, isFalse);
      expect(controller.testing, isEmpty);
      answer.complete(const Delay(name: 'A', url: _url, value: 5));
      await _settle();
      expect(controller.delays, isEmpty);
      verify(() => backend.testDelay(any(), url: _url)).called(2);
    },
  );

  test(
    'a missing Core result preserves the previous measurement and ends the batch',
    () async {
      when(
        () => backend.testDelay('A', url: _url),
      ).thenAnswer((_) async => const Delay(name: 'A', url: _url, value: 8));
      await controller.testDelay('A', url: _url);
      when(
        () => backend.testDelay(any(), url: _url),
      ).thenAnswer((_) async => null);
      expect(await controller.testDelays(['A', 'B', 'C'], url: _url), isFalse);
      expect(controller.delayFor('A', _url), 8);
      expect(controller.delayFor('B', _url), isNull);
      expect(controller.testing, isEmpty);
      verifyNever(() => backend.testDelay('C', url: _url));
    },
  );
}
