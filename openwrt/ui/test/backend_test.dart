import 'dart:async';

import 'package:fl_clash/iping/backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/backend.dart';
import 'package:iping_openwrt/client.dart';

import 'fake_client.dart';

class _Client extends FakeRouterClient {
  Completer<Object?>? statusRequest;
  final status = <String, Object?>{};
  final responses = <String, Object? Function(Map<String, Object?>)>{};

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    if (method == 'status' && statusRequest != null) {
      return statusRequest!.future;
    }
    final result = await super.call(method, args);
    if (responses[method] case final response?) return response(args);
    if (method == 'status') return {...result! as Map, ...status};
    return result;
  }
}

void main() {
  test(
    'parallel resource reads share one immutable settings response and later reads stay fresh',
    () async {
      final client = _Client();
      final backend = RouterBackend(client);
      await (
        backend.readProfileResources(),
        Future.value(backend.customProxies.read()),
        Future.value(backend.ruleProviders.read()),
        Future.value(backend.filters.read()),
        Future.value(backend.addedRules.read()),
        Future.value(backend.scripts.read()),
      ).wait;
      expect(
        client.calls.where((method) => method == 'settings_get'),
        hasLength(1),
      );
      await backend.readSettings();
      expect(
        client.calls.where((method) => method == 'settings_get'),
        hasLength(2),
      );
    },
  );

  test(
    'rule and script catalogs remain separate from scoped application',
    () async {
      final client = _Client();
      final backend = RouterBackend(client);
      const rule = IpingAddedRule(
        id: 'rule',
        rule: Rule(
          ruleAction: RuleAction.DOMAIN_REGEX,
          content: r'^(a,b)\.example$',
          ruleTarget: 'MATCH',
        ),
      );
      const script = IpingScript(
        id: 'script',
        label: 'Transform',
        content: 'function main(config) { return config; }',
      );
      await backend.addedRules.write([rule]);
      expect((await backend.addedRules.read()).single.toJson(), rule.toJson());
      expect(await backend.scripts.validate(script), isNull);
      await backend.scripts.write([script]);
      final scope = await backend.readProfileResources();
      expect(scope.bindings.isEmpty, isTrue);
      await backend.updateProfileResources(
        IpingProfileResources(
          profileId: scope.profileId,
          label: scope.label,
          bindings: const IpingResourceBindings(
            rules: {'rule'},
            script: 'script',
          ),
        ),
      );
      expect((await backend.readProfileResources()).bindings.rules, {'rule'});
      expect((await backend.readProfileResources()).bindings.script, 'script');
      client.resourceProfileId = 'another/8';
      await expectLater(
        backend.updateProfileResources(scope),
        throwsA(isA<IpingResourceException>()),
      );
      client.responses['validate_scripts'] = (_) => [false];
      await expectLater(
        backend.scripts.validate(script),
        throwsA(isA<RouterException>()),
      );
    },
  );

  test(
    'profile identity is checked again after loading resource catalogs',
    () async {
      final client = _Client();
      final backend = RouterBackend(client);
      final scope = await backend.readProfileResources();
      var reads = 0;
      client.responses['settings_get'] = (_) {
        if (++reads == 2) client.resourceProfileId = 'changed/9';
        return {
          'profile_id': client.resourceProfileId,
          'values': client.settings,
          'overrides': <String, bool>{},
        };
      };
      await expectLater(
        backend.updateProfileResources(scope),
        throwsA(isA<RouterException>()),
      );
      expect(client.settings['custom.bindings'], scope.bindings.toJson());
    },
  );

  test(
    'typed proxy and provider catalogs preserve ids and reject bad resources',
    () async {
      final client = _Client();
      final backend = RouterBackend(client);
      final proxy = IpingCustomProxy(
        id: '12345678901234567890',
        emptyOptions: const ['alpn'],
        definition: const {'name': 'Home', 'type': 'direct'},
      );
      expect(await backend.customProxies.validate(proxy), isNull);
      expect((await backend.customProxies.write([proxy])).single.id, proxy.id);
      expect(
        (await backend.customProxies.read()).single.emptyOptions,
        proxy.emptyOptions,
      );
      expect(client.settings['custom.proxies'], [proxy.toJson()]);
      const provider = IpingRuleProvider(
        id: 'provider-browser-id',
        label: 'Ads',
        url: 'https://example.com/ads.yaml',
        behavior: 'domain',
      );
      expect(await backend.ruleProviders.validate(provider), isNull);
      expect(
        (await backend.ruleProviders.write([provider])).single.toJson(),
        provider.toJson(),
      );
      expect(client.settings['custom.rule-providers'], [provider.toJson()]);
      final writes = client.calls
          .where((method) => method == 'settings_set')
          .length;
      await expectLater(
        backend.customProxies.write([proxy, proxy]),
        throwsA(isA<IpingResourceException>()),
      );
      await expectLater(
        backend.ruleProviders.write([
          const IpingRuleProvider(id: 'local', label: 'Local'),
        ]),
        throwsA(isA<IpingResourceException>()),
      );
      expect(
        client.calls.where((method) => method == 'settings_set').length,
        writes,
      );
      client.responses['validate_proxies'] = (_) => [42];
      await expectLater(
        backend.customProxies.validate(proxy),
        throwsA(isA<RouterException>()),
      );
    },
  );

  test(
    'filter resources preserve order and validate through the Agent',
    () async {
      final client = _Client();
      final backend = RouterBackend(client);
      expect(backend.resourceKinds, contains(IpingResourceKind.groupIcons));
      expect(
        backend.resourceKinds,
        isNot(contains(IpingResourceKind.iconSets)),
      );
      const filters = [
        Filter(label: 'Z', regex: r'(?<=hk)1`jp'),
        Filter(label: 'A', regex: 'us'),
      ];
      expect(await backend.filters.validate(filters.first), isNull);
      await backend.filters.write(filters);
      expect(await backend.filters.read(), filters);
      expect(client.settings['custom.filters'], [
        for (final filter in filters) filter.toJson(),
      ]);
      final writes = client.calls
          .where((method) => method == 'settings_set')
          .length;
      await expectLater(
        backend.filters.write([filters.first, filters.first]),
        throwsA(isA<IpingResourceException>()),
      );
      expect(
        client.calls.where((method) => method == 'settings_set').length,
        writes,
      );
      client.responses['validate_filters'] = (_) => [42];
      await expectLater(
        backend.filters.validate(filters.first),
        throwsA(isA<RouterException>()),
      );
    },
  );

  test(
    'telemetry maps typed snapshots and resets the rate after disconnect',
    () async {
      final client = _Client();
      var now = DateTime.utc(2026);
      var up = 100;
      var down = 200;
      client.responses['telemetry'] = (_) => {
        'running': client.running,
        'upload': up,
        'download': down,
        'connections': 4,
        'memory': 4096,
        'mode': client.mode,
      };
      final backend = RouterBackend(client, clock: () => now);
      final first = await backend.readTelemetry();
      expect(first.traffic.latest, const Traffic());
      up = 1100;
      down = 2200;
      now = now.add(const Duration(seconds: 2));
      final next = await backend.readTelemetry();
      expect(next.connections, 4);
      expect(next.memory, 4096);
      expect(next.traffic.latest, const Traffic(up: 500, down: 1000));
      expect(first.traffic.total, const Traffic(up: 100, down: 200));
      client.running = false;
      await backend.readState();
      await backend.setMode(Mode.global);
      expect((await backend.readTelemetry()).mode, Mode.global);
      client.running = true;
      now = now.add(const Duration(seconds: 2));
      expect((await backend.readTelemetry()).traffic.latest, const Traffic());
      expect(
        client.requests.singleWhere((request) => request.$1 == 'set_mode').$2,
        {'mode': 'global'},
      );
    },
  );

  test('router status maps to the shared state and capabilities', () async {
    final client = _Client()
      ..status.addAll({'synced': 1792890000, 'site': 'https://example.com'});
    final IpingBackend backend = RouterBackend(client);
    final state = await backend.readState();
    expect(state.initialized, isTrue);
    expect(state.signedIn, isTrue);
    expect(state.connected, isTrue);
    expect(state.email, 'user@example.com');
    expect(state.nodes, 2);
    expect(state.site, 'https://example.com');
    expect(state.updated!.millisecondsSinceEpoch, 1792890000000);
    expect(
      backend.capabilities,
      contains(IpingBackendCapability.routerNetwork),
    );
    expect(
      backend.capabilities,
      isNot(contains(IpingBackendCapability.systemProxy)),
    );

    client.status['synced'] = 0;
    expect((await backend.readState()).updated, isNull);
  });

  test(
    'connection waits for the router job after the RPC acknowledgement',
    () async {
      final client = _Client()..statusRequest = Completer<Object?>();
      final IpingBackend backend = RouterBackend(client);
      var completed = false;
      final operation = backend.setConnected(true).then((accepted) {
        completed = true;
        return accepted;
      });
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, contains('connect'));
      expect(completed, isFalse);
      client.statusRequest!.complete({
        'busy': false,
        'job': {'done': true},
      });
      expect(await operation, isTrue);
    },
  );

  test(
    'job failures propagate through connection and settings operations',
    () async {
      final client = _Client()..jobError = 'service_failed';
      final backend = RouterBackend(client);
      final error = isA<RouterException>().having(
        (value) => value.message,
        'message',
        'service_failed',
      );
      await expectLater(backend.setConnected(true), throwsA(error));
      await expectLater(backend.updateSettings({'ipv6': true}), throwsA(error));
      expect((await backend.readState()).busy, isFalse);
    },
  );

  test('subscription and logout use the shared backend commands', () async {
    final client = _Client();
    final IpingBackend backend = RouterBackend(client);
    await backend.synchronize();
    expect(client.calls, contains('sync'));
    await backend.signOut();
    expect(client.calls, contains('logout'));
    expect((await backend.readState()).signedIn, isFalse);
  });

  test(
    'settings use the shared snapshot and preserve router-only fields',
    () async {
      final client = _Client();
      client.settings['hosts'] = {
        'example.com': ['127.0.0.1', '::1'],
      };
      final IpingBackend backend = RouterBackend(client);
      final settings = await backend.readSettings();
      expect(settings.port('mixed-port'), 7890);
      expect(settings.stringMap('hosts'), {'example.com': '127.0.0.1,::1'});
      expect(settings.options('find-process-mode'), [
        'off',
        'strict',
        'always',
      ]);
      await backend.updateSettings({
        'global-ua': null,
        'mixed-port': 7900,
        'dns.enable': false,
        'custom.proxies': ['name: direct\ntype: direct'],
      });
      final request = client.requests.singleWhere(
        (request) => request.$1 == 'settings_set',
      );
      expect(request.$2['changes'], {
        'global-ua': '',
        'mixed-port': 7900,
        'dns.enable': false,
        'custom.proxies': ['name: direct\ntype: direct'],
      });
      expect((await backend.readSettings()).port('mixed-port'), 7900);
      expect(settings.port('mixed-port'), 7890);
    },
  );

  test('invalid settings batches never reach the router mutation', () async {
    final client = _Client();
    final IpingBackend backend = RouterBackend(client);
    for (final patch in <Map<String, Object?>>[
      {'ipv6': true, 'mixed-port': 0},
      {'ipv6': true, 'port': 80},
      {'ipv6': true, 'mixed-port': 49152},
      {'ipv6': true, 'port': 7890},
      {'ipv6': true, 'log-level': 'trace'},
      {'ipv6': true, 'allow-lan': 'true'},
      {'ipv6': true, 'global-ua': 'bad\nheader'},
      {
        'ipv6': true,
        'hosts': {'example.com': 127},
      },
      {'ipv6': true, 'unsupported': true},
      {'ipv6': true, 'dns.nameserver': List.filled(129, '1.1.1.1')},
    ]) {
      await expectLater(
        backend.updateSettings(patch),
        throwsA(isA<IpingSettingsException>()),
      );
      expect(client.settings['ipv6'], isFalse);
    }
    expect(client.calls, isNot(contains('settings_set')));
    client.calls.clear();
    await backend.updateSettings({});
    expect(client.calls, isEmpty);
  });

  test(
    'DNS overrides preserve false and empty values and reset with null',
    () async {
      final client = _Client();
      final IpingBackend backend = RouterBackend(client);
      expect(
        (await backend.readSettings()).overrides['dns.use-hosts'],
        isFalse,
      );
      await backend.updateSettings({
        'dns.use-hosts': false,
        'dns.nameserver': <String>[],
      });
      final snapshot = await backend.readSettings();
      expect(snapshot.overrides['dns.use-hosts'], isTrue);
      expect(snapshot.flag('dns.use-hosts'), isFalse);
      expect(snapshot['dns.nameserver'], isEmpty);
      await backend.updateSettings({'dns.use-hosts': null});
      final reset = await backend.readSettings();
      expect(reset.flag('dns.use-hosts'), isTrue);
      expect(reset.overrides['dns.use-hosts'], isFalse);
      expect(reset.overrides['dns.nameserver'], isTrue);
      expect(
        client.requests
            .where((request) => request.$1 == 'settings_set')
            .last
            .$2['changes'],
        {'dns.use-hosts': null},
      );
      await expectLater(
        backend.updateSettings({'dns.listen': 'not-a-listener'}),
        throwsA(isA<IpingSettingsException>()),
      );
    },
  );

  test(
    'proxy queries and mutations preserve typed selection and delay data',
    () async {
      final client = _Client();
      client.responses['proxies'] = (_) => {
        'groups': [
          {
            'name': 'Auto',
            'type': 'URLTest',
            'count': 65,
            'now': 'Node B',
            'fixed': 'Node A',
            'selected_index': 61,
          },
        ],
        'group': 'Auto',
        'offset': 60,
        'total': 65,
        'selected_index': 61,
        'items': [
          {
            'name': 'Node B',
            'type': 'Shadowsocks',
            'history': [
              {'delay': 37},
            ],
          },
        ],
      };
      final IpingBackend backend = RouterBackend(client);
      final page = await backend.readProxies(
        const IpingProxyQuery(
          group: 'Auto',
          offset: 60,
          query: 'node',
          sort: ProxiesSortType.delay,
          hideTimeout: true,
        ),
      );
      expect(page.groups.single.computed, isTrue);
      expect(page.groups.single.pinned, 'Node A');
      expect(page.selectedIndex, 61);
      expect(page.items.single.delay, 37);
      expect(client.requests.last.$2, {
        'group': 'Auto',
        'offset': 60,
        'query': 'node',
        'sort': 'delay',
        'hide_timeout': true,
      });
      await backend.selectProxy('Auto', '', closeConnections: true);
      expect(client.requests.last.$1, 'select_proxy');
      expect(client.requests.last.$2, {
        'group': 'Auto',
        'name': '',
        'close_connections': true,
      });
      final delay = await backend.testDelay(
        'Node B',
        url: 'https://example.com/delay',
      );
      expect(delay!.name, 'Node B');
      expect(delay.url, 'https://example.com/delay');
      expect(delay.value, 42);
    },
  );

  test(
    'full connection queries collect pages and keep filtering on the router',
    () async {
      final client = _Client();
      client.responses['connections'] = (args) {
        final offset = args['offset'] as int;
        return {
          'total': 65,
          'offset': offset,
          'items': [
            for (var i = offset; i < (offset == 0 ? 60 : 65); i++)
              {
                'id': '$i',
                'start': '2026-10-25T00:00:00Z',
                'metadata': {'network': 'tcp'},
                'chains': <String>[],
                'rule': 'MATCH',
                'rulePayload': '',
              },
          ],
        };
      };
      final IpingBackend backend = RouterBackend(client);
      final page = await backend.readConnections(
        const IpingConnectionQuery(query: 'TCP', limit: null),
      );
      expect(page.total, 65);
      expect(page.items.map((item) => item.id).toSet().length, 65);
      expect(
        client.requests
            .where((call) => call.$1 == 'connections')
            .map((call) => call.$2),
        [
          {'query': 'TCP', 'offset': 0},
          {'query': 'TCP', 'offset': 60},
        ],
      );
      await backend.closeConnection('42');
      expect(client.requests.last.$1, 'close_connection');
      expect(client.requests.last.$2, {'id': '42'});
      await backend.closeConnections();
      expect(client.requests.last.$1, 'close_connection');
      expect(client.requests.last.$2, {'id': ''});
      expect(await backend.readConnectionCount(), 1);
    },
  );

  test(
    'log snapshots parse records and retain the original export text',
    () async {
      final client = _Client();
      const line =
          r'time="2026-10-25T12:00:00Z" level=warn msg="connection\nfailed"';
      client.responses['logs'] = (_) => {
        'lines': [line, 'plain diagnostic'],
      };
      final IpingBackend backend = RouterBackend(client);
      final snapshot = await backend.readLogs();
      expect(snapshot.source, '$line\nplain diagnostic');
      expect(snapshot.logs.first.payload, 'connection\nfailed');
      expect(snapshot.logs.first.logLevel.name, 'warning');
      expect(snapshot.logs.last.payload, 'plain diagnostic');
    },
  );
}
