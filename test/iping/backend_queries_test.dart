import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/logs/controller.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

const _url = 'https://example.com/delay';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Core core;
  late ProviderContainer container;
  late IpingBackend backend;

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(
      const ChangeProxyParams(groupName: 'G', proxyName: 'P'),
    );
  });

  setUp(() {
    core = _Core();
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(
              id: 1,
              autoUpdateDuration: Duration.zero,
              selectedMap: {'G': 'P65'},
            ),
          ]),
        ),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
      ],
    );
    final settings = container.listen(appSettingProvider, (_, _) {});
    addTearDown(settings.close);
    container.read(appSettingProvider.notifier).value = const AppSettingProps(
      testUrl: _url,
    );
    backend = container.read(ipingBackendProvider);
  });
  tearDown(() => container.dispose());

  test(
    'native resources keep the preset owner and native regex validation',
    () async {
      final store = backend.filters;
      expect(backend.resourceKinds, contains(IpingResourceKind.iconSets));
      expect(
        backend.resourceKinds,
        isNot(contains(IpingResourceKind.groupIcons)),
      );
      expect(store.itemLimit, isNull);
      when(() => core.validateFilters(any())).thenAnswer((_) async => ['']);
      const filter = Filter(label: 'Asia', regex: r'(?<=hk)1`jp');
      expect(await store.validate(filter), isNull);
      await store.write([filter]);
      expect(container.read(appSettingProvider).filters, [filter]);
      expect(await store.read(), [filter]);
      verify(() => core.validateFilters([filter.regex])).called(1);
      await expectLater(
        store.write([filter, filter]),
        throwsA(isA<IpingResourceException>()),
      );
      expect(await store.read(), [filter]);
      await store.write([]);
      expect(await store.read(), isEmpty);
    },
  );

  test('proxy selection shares pin, unpin and unsupported-group behavior', () {
    for (final type in ['Selector', 'URLTest', 'Fallback', 'LoadBalance']) {
      final group = IpingProxyGroup(
        name: 'G',
        type: type,
        count: 2,
        pinned: 'P1',
      );
      expect(group.selectionFor('P1'), switch (type) {
        'Selector' => 'P1',
        'LoadBalance' => null,
        _ => '',
      });
      expect(group.selectionFor('P2'), type == 'LoadBalance' ? null : 'P2');
    }
  });

  test(
    'telemetry uses event traffic and the existing Core statistics',
    () async {
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 50, down: 100));
      container.read(totalTrafficProvider.notifier).value = const Traffic(
        up: 500,
        down: 1000,
      );
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      when(core.getConnectionCount).thenAnswer((_) async => 3);
      when(
        core.getMemoryStats,
      ).thenAnswer((_) async => const CoreMemoryStats(rss: 1024));
      await backend.setMode(Mode.direct);
      final snapshot = await backend.readTelemetry();
      expect(snapshot.mode, Mode.direct);
      expect(snapshot.connections, 3);
      expect(snapshot.memory, 1024);
      expect(snapshot.traffic.latest, const Traffic(up: 50, down: 100));
      expect(snapshot.traffic.total, const Traffic(up: 500, down: 1000));
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 25));
      expect(snapshot.traffic.latest, const Traffic(up: 50, down: 100));
      expect(
        container.read(ipingTrafficProvider).latest,
        const Traffic(up: 25),
      );
    },
  );

  test('telemetry avoids Core calls while it is disconnected', () async {
    await backend.setMode(Mode.direct);
    final snapshot = await backend.readTelemetry();
    expect(snapshot.mode, Mode.direct);
    expect(snapshot.memory, 0);
    expect(snapshot.connections, 0);
    verifyNever(core.getMemoryStats);
    verifyNever(core.getConnectionCount);
  });

  test(
    'proxy pages preserve the selection and filter timed-out nodes',
    () async {
      container.read(groupsProvider.notifier).value = [
        Group(
          name: 'G',
          type: GroupType.Selector,
          now: 'P0',
          all: List.generate(
            75,
            (index) => Proxy(name: 'P$index', type: 'Shadowsocks'),
          ),
        ),
        const Group(name: 'hidden', type: GroupType.Selector, hidden: true),
      ];
      container.read(delayDataSourceProvider.notifier).value = {
        _url: {'P1': -1, 'P2': 20},
      };
      final page = await backend.readProxies(
        const IpingProxyQuery(offset: 60, hideTimeout: true),
      );
      expect(page.groups.map((group) => group.name), ['G']);
      expect(page.groups.single.selected, 'P65');
      expect(page.total, 74);
      expect(page.offset, 60);
      expect(page.selectedIndex, 64);
      expect(page.items.first.name, 'P61');
      expect(page.items.length, 14);

      final filtered = await backend.readProxies(
        const IpingProxyQuery(
          query: 'p2 SHADOWSOCKS',
          sort: ProxiesSortType.name,
        ),
      );
      expect(filtered.items.map((item) => item.name), [
        'P2',
        'P20',
        'P21',
        'P22',
        'P23',
        'P24',
        'P25',
        'P26',
        'P27',
        'P28',
        'P29',
      ]);
      expect(filtered.items.first.delay, 20);
    },
  );

  test(
    'connection pages filter and sort while full reads keep Core ordering',
    () async {
      final items = List.generate(
        65,
        (index) => TrackerInfo(
          id: '$index',
          start: DateTime.utc(2026, 1, 1, 0, index),
          metadata: Metadata(
            host: 'target-$index.example',
            network: index.isEven ? 'tcp' : 'udp',
          ),
          chains: const ['Proxy'],
          rule: 'MATCH',
          rulePayload: '',
        ),
      );
      when(core.getConnections).thenAnswer((_) async => items);
      when(core.getConnectionCount).thenAnswer((_) async => items.length);
      expect(await backend.readConnectionCount(), 65);
      final page = await backend.readConnections(
        const IpingConnectionQuery(query: 'TARGET tcp', offset: 1, limit: 2),
      );
      expect(page.total, 33);
      expect(page.items.map((item) => item.id), ['62', '60']);
      final full = await backend.readConnections(
        const IpingConnectionQuery(limit: null),
      );
      expect(full.items, same(items));
    },
  );

  test(
    'selecting through the backend saves the pick and applies close policy',
    () async {
      when(() => core.changeProxy(any())).thenAnswer(
        (_) async => const ChangeProxyResult(message: '', changed: true),
      );
      when(core.closeConnections).thenAnswer((_) async => true);
      expect(
        await backend.selectProxy('G', 'P2', closeConnections: true),
        isTrue,
      );
      expect(container.read(currentProfileProvider)!.selectedMap['G'], 'P2');
      verify(
        () => core.changeProxy(
          const ChangeProxyParams(groupName: 'G', proxyName: 'P2'),
        ),
      ).called(1);
      verify(core.closeConnections).called(1);
    },
  );

  test(
    'delay replies distinguish an unknown value from a missing reply',
    () async {
      when(
        () => core.asyncTestDelay(_url, 'P'),
      ).thenAnswer((_) async => const Delay(name: 'P', url: _url));
      final result = await backend.testDelay('P', url: _url);
      expect(result, isNotNull);
      expect(result!.value, isNull);
      when(() => core.asyncTestDelay(_url, 'P')).thenAnswer((_) async => null);
      expect(await backend.testDelay('P', url: _url), isNull);
    },
  );

  test('log snapshots use the same filtering and pause controller', () async {
    container
        .read(logsProvider.notifier)
        .add(
          const Log(
            logLevel: LogLevel.warning,
            payload: 'connection failed',
            dateTime: '2026-10-25',
          ),
        );
    container
        .read(logsProvider.notifier)
        .add(const Log(payload: 'connected', dateTime: '2026-10-25'));
    final snapshot = await backend.readLogs();
    final controller = LogListController()..setLogs(snapshot.logs);
    addTearDown(controller.dispose);
    controller.search('FAILED warning');
    expect(controller.value.list.single.payload, 'connection failed');
    controller.search('');
    controller.updateKeywords(['info']);
    expect(controller.value.list.single.payload, 'connected');
    controller.setAutoScrollToEnd(false);
    controller.setLogs([const Log(payload: 'latest', dateTime: '2026-10-25')]);
    expect(
      controller.value.logs.map((log) => log.payload),
      contains('connected'),
    );
  });

  test('router log lines retain timestamp, severity and escaped payload', () {
    final log = Log.fromLine(
      r'time="2026-10-25T12:00:00+08:00" level=warn msg="connection\nfailed"',
    );
    expect(log.dateTime, '2026-10-25T12:00:00+08:00');
    expect(log.logLevel, LogLevel.warning);
    expect(log.payload, 'connection\nfailed');
    expect(Log.fromLine('plain diagnostic').payload, 'plain diagnostic');
    expect(Log.fromLine('plain diagnostic').dateTime, isEmpty);
  });
}
