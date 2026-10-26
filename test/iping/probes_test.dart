import 'dart:async';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/probes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Backend extends Mock implements IpingBackend {}

const _route = RouteState(
  coreEpoch: 1,
  picksVersion: 1,
  proxied: true,
  live: true,
  synced: true,
);
const _quality = IpQuality(
  ip: '203.0.113.7',
  source: IpQualitySource.identMe,
  type: IpType.hosting,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Backend backend;
  late IpingProbes probes;

  setUp(() {
    backend = _Backend();
    when(backend.readProbeRoute).thenAnswer((_) async => _route);
    when(() => backend.readIpQuality(any())).thenAnswer((_) async => _quality);
    probes = IpingProbes(backend);
  });
  tearDown(() => probes.dispose());

  test('unchanged route polls do not notify probe subscribers', () async {
    await probes.refreshRoute();
    var notifications = 0;
    probes.addListener(() => notifications++);
    await probes.refreshRoute();
    expect(notifications, 0);
    when(
      backend.readProbeRoute,
    ).thenAnswer((_) async => _route.copyWith(coreEpoch: 2));
    await probes.refreshRoute();
    expect(notifications, greaterThan(0));
  });

  test('route reads are shared by outbound and service watchers', () async {
    final route = Completer<RouteState>();
    when(backend.readProbeRoute).thenAnswer((_) => route.future);
    when(
      () => backend.lookupOutboundIp(''),
    ).thenAnswer((_) async => const ProbeAnswer());
    when(
      () => backend.checkServices('', [ServiceTarget.google]),
    ).thenAnswer((_) async => {});
    probes.outbound.watch('');
    probes.services.watch(ServiceTarget.google);
    final reading = probes.refreshRoute();
    route.complete(_route);
    await reading;
    await _settle();
    verify(backend.readProbeRoute).called(1);
    verify(() => backend.lookupOutboundIp('')).called(1);
    verify(() => backend.checkServices('', [ServiceTarget.google])).called(1);
  });

  test(
    'a new route can finish first and rejects the previous route answer',
    () async {
      final old = Completer<ProbeAnswer<IpInfo>>();
      final current = Completer<ProbeAnswer<IpInfo>>();
      var calls = 0;
      when(
        () => backend.lookupOutboundIp(''),
      ).thenAnswer((_) => ++calls == 1 ? old.future : current.future);
      probes.outbound.watch('');
      await _settle();
      when(
        backend.readProbeRoute,
      ).thenAnswer((_) async => _route.copyWith(coreEpoch: 2));
      await probes.refreshRoute();
      await _settle();
      current.complete(
        const ProbeAnswer(
          value: IpInfo(ip: '203.0.113.7', countryCode: 'JP'),
          coreEpoch: 2,
          picksVersion: 1,
        ),
      );
      await _settle();
      old.complete(
        const ProbeAnswer(
          value: IpInfo(ip: '203.0.113.8', countryCode: 'US'),
          coreEpoch: 1,
          picksVersion: 1,
        ),
      );
      await _settle();
      expect(probes.outbound.state.valueOf('')?.ip, '203.0.113.7');
      expect(probes.outbound.state.entryOf('').phase, ProbePhase.fresh);
      expect(probes.qualityOf('203.0.113.7'), _quality);
      verifyNever(() => backend.readIpQuality('203.0.113.8'));
    },
  );

  test(
    'stopped proxy checks DIRECT and does not reuse a proxied answer',
    () async {
      when(
        backend.readProbeRoute,
      ).thenAnswer((_) async => _route.copyWith(coreEpoch: 0, proxied: false));
      when(() => backend.lookupOutboundIp('DIRECT')).thenAnswer(
        (_) async => const ProbeAnswer(
          value: IpInfo(ip: '203.0.113.7', countryCode: 'US'),
          coreEpoch: 0,
          picksVersion: 1,
        ),
      );
      probes.outbound.watch('');
      await _settle();
      expect(probes.outbound.state.valueOf('')?.ip, '203.0.113.7');
      verify(() => backend.lookupOutboundIp('DIRECT')).called(1);
    },
  );

  test(
    'a failed route read recovers the watched targets on the next read',
    () async {
      when(backend.readProbeRoute).thenThrow(StateError('offline'));
      when(() => backend.lookupOutboundIp('')).thenAnswer(
        (_) async => const ProbeAnswer(
          value: IpInfo(ip: '203.0.113.7', countryCode: 'US'),
          coreEpoch: 1,
          picksVersion: 1,
        ),
      );
      probes.outbound.watch('');
      await _settle();
      expect(probes.error, isNotNull);
      expect(probes.outbound.state.valueOf(''), isNull);
      when(backend.readProbeRoute).thenAnswer((_) async => _route);
      await probes.refreshRoute();
      await _settle();
      expect(probes.error, isNull);
      expect(probes.outbound.state.entryOf('').phase, ProbePhase.fresh);
    },
  );

  test('quality requests coalesce and keep successful answers', () async {
    final result = Completer<IpQuality>();
    when(() => backend.readIpQuality(any())).thenAnswer((_) => result.future);
    final first = probes.loadQuality('203.0.113.7');
    final second = probes.loadQuality('203.0.113.7');
    expect(probes.isQualityLoading('203.0.113.7'), isTrue);
    result.complete(_quality);
    await Future.wait([first, second]);
    await probes.loadQuality('203.0.113.7');
    verify(() => backend.readIpQuality('203.0.113.7')).called(1);
    expect(probes.isQualityLoading('203.0.113.7'), isFalse);
    expect(probes.qualityOf('203.0.113.7'), _quality);
  });

  test('quality failures cool down and explicit retries can recover', () async {
    when(
      () => backend.readIpQuality(any()),
    ).thenThrow(StateError('rate limited'));
    await probes.loadQuality('203.0.113.7');
    await probes.loadQuality('203.0.113.7');
    verify(() => backend.readIpQuality('203.0.113.7')).called(1);
    expect(probes.qualityErrorOf('203.0.113.7'), isNotNull);
    when(() => backend.readIpQuality(any())).thenAnswer((_) async => _quality);
    await probes.loadQuality('203.0.113.7', force: true);
    expect(probes.qualityErrorOf('203.0.113.7'), isNull);
    expect(probes.qualityOf('203.0.113.7'), _quality);
  });
  test('returning to the foreground retries failed watched probes', () async {
    var calls = 0;
    when(() => backend.lookupOutboundIp('')).thenAnswer((_) async {
      calls++;
      return const ProbeAnswer();
    });
    probes.outbound.watch('');
    await _settle();
    expect(probes.outbound.state.entryOf('').phase, ProbePhase.failed);
    probes.setVisible(false);
    await probes.refreshRoute();
    expect(calls, 1);
    when(() => backend.lookupOutboundIp('')).thenAnswer((_) async {
      calls++;
      return const ProbeAnswer(
        value: IpInfo(ip: '203.0.113.7', countryCode: 'US'),
        coreEpoch: 1,
        picksVersion: 1,
      );
    });
    probes.setVisible(true);
    await _settle();
    expect(calls, 2);
    expect(probes.outbound.state.entryOf('').phase, ProbePhase.fresh);
  });
}
