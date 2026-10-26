import 'dart:async';

import 'package:fl_clash/common/ip_quality.dart';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/site_config.dart';

import 'client.dart';

typedef _SettingsSnapshot = ({
  IpingSettings settings,
  String profileId,
  String label,
});

class RouterBackend implements IpingBackend {
  RouterBackend(this.client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final RouterClient client;
  final DateTime Function() _clock;
  final _traffic = IpingTrafficSampler();
  Future<_SettingsSnapshot>? _settingsRequest;

  @override
  Future<IpQuality> readIpQuality(String ip) =>
      lookupIpQualityUsing((url, _) async {
        final data = _object(await client.call('ip_quality', {'url': url}));
        if (data['error'] == 'timeout') throw TimeoutException('ip_quality');
        if (data['error'] case final String error when error.isNotEmpty) {
          throw RouterException(error);
        }
        return (
          statusCode: (data['status'] as num?)?.toInt() ?? 0,
          body: data['body'] as String? ?? '',
        );
      }, ip);

  @override
  Future<RouteState> readProbeRoute() async {
    final data = _object(await client.call('probe_route'));
    return RouteState(
      coreEpoch: (data['core-epoch'] as num?)?.toInt() ?? 0,
      picksVersion: (data['picks-version'] as num?)?.toInt() ?? 0,
      picks: _object(
        data['picks'],
      ).map((key, value) => MapEntry(key, value as String)),
      proxied: data['proxied'] == true,
      synced: true,
      live: true,
    );
  }

  @override
  Future<ProbeAnswer<IpInfo>> lookupOutboundIp(String proxyName) async {
    final data = _object(
      await client.call('outbound_ip', {
        'proxy_name': proxyName,
        'urls': ipInfoSources.keys.toList(),
      }),
    );
    return ProbeAnswer(
      value: parseOutboundIpBody(
        url: data['url'] as String?,
        body: data['body'] as String?,
        error: data['error'] as String?,
      ),
      coreEpoch: (data['core-epoch'] as num?)?.toInt(),
      picksVersion: (data['picks-version'] as num?)?.toInt(),
      chains: (data['chains'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  Future<Map<ServiceTarget, ProbeAnswer<ServiceCheck>>> checkServices(
    String proxyName,
    List<ServiceTarget> targets,
  ) async {
    final items = await Future.wait([
      for (final target in targets)
        client.call('service_check', {
          'proxy_name': proxyName,
          'names': [target.id],
        }),
    ]);
    final checks = <ServiceTarget, ProbeAnswer<ServiceCheck>>{};
    for (final rows in items) {
      for (final item in rows as List) {
        final data = _object(item);
        final target = ServiceTarget.byId(data['name'] as String? ?? '');
        if (target == null) continue;
        final check = ServiceCheck.fromJson(data);
        checks[target] = ProbeAnswer(
          value: check,
          coreEpoch: check.coreEpoch,
          picksVersion: check.picksVersion,
          chains: check.chains,
        );
      }
    }
    return checks;
  }

  Future<_SettingsSnapshot> _settingsSnapshot() {
    if (_settingsRequest case final pending?) return pending;
    late final Future<_SettingsSnapshot> request;
    request = _readSettingsSnapshot().whenComplete(() {
      if (identical(_settingsRequest, request)) _settingsRequest = null;
    });
    _settingsRequest = request;
    return request;
  }

  Future<_SettingsSnapshot> _readSettingsSnapshot() async {
    final data = _object(await client.call('settings_get'));
    return (
      settings: IpingSettings(
        _object(data['values']),
        overrides: _object(
          data['overrides'],
        ).map((key, value) => MapEntry(key, value == true)),
      ),
      profileId: data['profile_id'] as String? ?? '',
      label: data['profile_label'] as String? ?? '',
    );
  }

  @override
  Set<IpingResourceKind> get resourceKinds => const {
    IpingResourceKind.proxies,
    IpingResourceKind.ruleProviders,
    IpingResourceKind.filters,
    IpingResourceKind.rules,
    IpingResourceKind.scripts,
    IpingResourceKind.groupIcons,
  };

  @override
  late final IpingResourceStore<Filter> filters = _RouterFilters(this);

  @override
  late final IpingResourceStore<IpingCustomProxy> customProxies =
      _RouterCustomProxies(this);

  @override
  late final IpingResourceStore<IpingRuleProvider> ruleProviders =
      _RouterRuleProviders(this);

  @override
  late final IpingResourceStore<IpingAddedRule> addedRules = _RouterAddedRules(
    this,
  );
  @override
  late final IpingResourceStore<IpingScript> scripts = _RouterScripts(this);

  @override
  Future<IpingProfileResources> readProfileResources() async {
    final snapshot = await _settingsSnapshot();
    return IpingProfileResources(
      profileId: snapshot.profileId,
      label: snapshot.label,
      bindings: IpingResourceBindings.fromJson(
        Map<String, Object?>.from(
          snapshot.settings['custom.bindings'] as Map? ?? const {},
        ),
      ),
    );
  }

  @override
  Future<void> updateProfileResources(IpingProfileResources value) async {
    final current = await readProfileResources();
    if (value.profileId.isEmpty || current.profileId != value.profileId) {
      throw const IpingResourceException(IpingResourceIssue.missing);
    }
    final (proxies, providers, presets, ruleItems, scriptItems) = await (
      Future.value(customProxies.read()),
      Future.value(ruleProviders.read()),
      Future.value(filters.read()),
      Future.value(addedRules.read()),
      Future.value(scripts.read()),
    ).wait;
    validateIpingResourceBindings(
      value.bindings,
      proxies: proxies.map((item) => item.id).toSet(),
      providers: providers.map((item) => item.id).toSet(),
      filters: presets.map((item) => item.label).toSet(),
      rules: ruleItems.map((item) => item.id).toSet(),
      scripts: scriptItems.map((item) => item.id).toSet(),
    );
    await _runJob('settings_set', {
      'profile_id': value.profileId,
      'changes': {'custom.bindings': value.bindings.toJson()},
    });
  }

  @override
  Set<IpingBackendCapability> get capabilities => const {
    IpingBackendCapability.tun,
    IpingBackendCapability.routerNetwork,
  };

  Future<Map<String, dynamic>> _status() async =>
      Map<String, dynamic>.from(await client.call('status') as Map);

  @override
  Future<IpingBackendState> readState() async {
    final status = await _status();
    if (status['running'] != true) _traffic.reset();
    final synced = (status['synced'] as num?)?.toInt();
    return IpingBackendState(
      initialized: true,
      signedIn: status['logged_in'] == true,
      connected: status['running'] == true,
      busy: status['busy'] == true,
      nodes: (status['nodes'] as num?)?.toInt() ?? 0,
      email: status['email'] as String? ?? '',
      site: status['site'] as String? ?? 'https://iping.my',
      updated: synced == null || synced <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(synced * 1000),
    );
  }

  @override
  Future<IpingSiteConfig> readSiteConfig() async {
    final state = await readState();
    final data = Map<String, dynamic>.from(
      await client.call('site_config') as Map? ?? const {},
    );
    return IpingSiteConfig.fromJson(data, site: state.site);
  }

  @override
  Future<IpingUserInfo?> readAccount() async {
    final value = await client.call('account');
    return value == null ? null : IpingUserInfo.fromJson(_object(value));
  }

  @override
  Future<IpingDashboardSnapshot> readDashboard() async =>
      IpingDashboardSnapshot.fromJson(_object(await client.call('dashboard')));

  @override
  Future<void> signIn({bool register = false}) async {
    await client.signIn(register: register);
    if ((await readState()).signedIn) await _waitForJob();
  }

  @override
  void cancelSignIn() => client.cancelSignIn();

  @override
  Future<void> synchronize() => _runJob('sync');

  @override
  Future<bool> setConnected(bool connected) async {
    await _runJob(connected ? 'connect' : 'disconnect');
    return true;
  }

  @override
  Future<void> setMode(Mode mode) async {
    await client.call('set_mode', {'mode': mode.name});
  }

  @override
  Future<IpingTelemetry> readTelemetry() async {
    final data = _object(await client.call('telemetry'));
    final running = data['running'] != false;
    if (!running) _traffic.reset();
    return IpingTelemetry(
      traffic: running
          ? _traffic.add(
              Traffic(
                up: (data['upload'] as num?)?.toInt() ?? 0,
                down: (data['download'] as num?)?.toInt() ?? 0,
              ),
              _clock(),
            )
          : const IpingTrafficSnapshot.empty(),
      connections: (data['connections'] as num?)?.toInt() ?? 0,
      memory: (data['memory'] as num?)?.toInt() ?? 0,
      mode: Mode.values.byName(data['mode'] as String? ?? 'rule'),
    );
  }

  @override
  Future<void> signOut() => _runJob('logout');

  @override
  Future<IpingProxyPage> readProxies([
    IpingProxyQuery query = const IpingProxyQuery(),
  ]) async {
    final data = _object(
      await client.call('proxies', {
        'group': query.group,
        'offset': query.offset,
        'query': query.query,
        'sort': query.sort.name,
        'hide_timeout': query.hideTimeout,
      }),
    );
    return IpingProxyPage(
      groups: [
        for (final raw in data['groups'] as List? ?? const [])
          _group(_object(raw)),
      ],
      group: data['group'] as String? ?? '',
      items: [
        for (final raw in data['items'] as List? ?? const [])
          _node(_object(raw)),
      ],
      total: (data['total'] as num?)?.toInt() ?? 0,
      offset: (data['offset'] as num?)?.toInt() ?? 0,
      selectedIndex: (data['selected_index'] as num?)?.toInt() ?? -1,
    );
  }

  @override
  Future<bool> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) async {
    await client.call('select_proxy', {
      'group': group,
      'name': name,
      'close_connections': closeConnections,
    });
    return true;
  }

  @override
  Future<Delay?> testDelay(String name, {required String url}) async {
    final data = _object(
      await client.call('delay_proxy', {'name': name, 'url': url}),
    );
    return Delay(name: name, url: url, value: (data['delay'] as num?)?.toInt());
  }

  @override
  Future<IpingConnectionPage> readConnections([
    IpingConnectionQuery query = const IpingConnectionQuery(),
  ]) async {
    var offset = query.offset;
    final items = <TrackerInfo>[];
    final seen = <String>{};
    var total = 0;
    int? initialTotal;
    var start = offset;
    while (true) {
      final data = _object(
        await client.call('connections', {
          'query': query.query,
          'offset': offset,
        }),
      );
      final page = [
        for (final raw in data['items'] as List? ?? const [])
          TrackerInfo.fromJson(_object(raw)),
      ];
      final actualOffset = (data['offset'] as num?)?.toInt() ?? offset;
      if (items.isEmpty) start = actualOffset;
      if (actualOffset < offset && items.isNotEmpty) break;
      items.addAll(page.where((item) => seen.add(item.id)));
      total = (data['total'] as num?)?.toInt() ?? 0;
      initialTotal ??= total;
      final next = actualOffset + page.length;
      if (page.isEmpty ||
          next >= initialTotal ||
          (query.limit != null && items.length >= query.limit!)) {
        break;
      }
      offset = next;
    }
    return IpingConnectionPage(
      items: query.limit == null ? items : items.take(query.limit!).toList(),
      total: total,
      offset: start,
    );
  }

  @override
  Future<int> readConnectionCount() async {
    final data = _object(await client.call('telemetry'));
    return (data['connections'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> closeConnection(String id) async {
    await client.call('close_connection', {'id': id});
  }

  @override
  Future<void> closeConnections() => closeConnection('');

  @override
  Future<IpingLogSnapshot> readLogs() async {
    final data = _object(await client.call('logs'));
    final lines = (data['lines'] as List? ?? const []).cast<String>();
    return IpingLogSnapshot(
      logs: lines.map(Log.fromLine).toList(),
      source: lines.join('\n'),
    );
  }

  @override
  Future<IpingSettings> readSettings() async =>
      (await _settingsSnapshot()).settings;

  @override
  Future<void> updateSettings(Map<String, Object?> changes) async {
    if (changes.isEmpty) return;
    final patch = IpingSettings(changes).values;
    final settings = await readSettings();
    settings.validate(patch);
    await _runJob('settings_set', {
      'changes': {
        ...patch,
        if (patch.containsKey('global-ua'))
          'global-ua': patch['global-ua'] ?? '',
      },
    });
  }

  Future<void> _runJob(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    await client.call(method, args);
    await _waitForJob();
  }

  Future<void> _waitForJob() async {
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (true) {
      final status = await _status();
      if (status['busy'] != true) {
        final job = status['job'];
        if (job is Map && job['done'] == true && job['error'] is String) {
          throw RouterException(job['error'] as String);
        }
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const RouterException('service_failed');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }
}

class _RouterFilters implements IpingResourceStore<Filter> {
  const _RouterFilters(this.backend);
  final RouterBackend backend;

  @override
  int get itemLimit => 128;

  @override
  Future<List<Filter>> read() async {
    final settings = await backend.readSettings();
    return [
      for (final item in settings['custom.filters'] as List? ?? const [])
        Filter.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  @override
  Future<List<Filter>> write(List<Filter> items) async {
    validateIpingFilters(items, limit: itemLimit);
    await backend.updateSettings({
      'custom.filters': [for (final item in items) item.toJson()],
    });
    return read();
  }

  @override
  Future<String?> validate(Filter item) async {
    if (!isIpingFilterValid(item)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    final errors = await backend.client.call('validate_filters', {
      'filters': [item.regex],
    });
    if (errors is! List || errors.length != 1 || errors.single is! String) {
      throw const RouterException('invalid_response');
    }
    return (errors.single as String).isEmpty ? null : errors.single as String;
  }
}

Map<String, dynamic> _object(Object? value) =>
    Map<String, dynamic>.from(value as Map);

IpingProxyGroup _group(Map<String, dynamic> data) => IpingProxyGroup(
  name: data['name'] as String,
  type: data['type'] as String? ?? '',
  count: (data['count'] as num?)?.toInt() ?? 0,
  selected: data['now'] as String? ?? '',
  pinned: data['fixed'] as String? ?? '',
  icon: data['icon'] as String? ?? '',
  selectedIndex: (data['selected_index'] as num?)?.toInt() ?? -1,
);

IpingProxyNode _node(Map<String, dynamic> data) {
  final history = data['history'] as List? ?? const [];
  return IpingProxyNode(
    name: data['name'] as String,
    type: data['type'] as String? ?? '',
    selected: data['now'] as String? ?? '',
    delay: history.isEmpty
        ? null
        : (_object(history.last)['delay'] as num?)?.toInt(),
  );
}

class _RouterCustomProxies implements IpingResourceStore<IpingCustomProxy> {
  const _RouterCustomProxies(this.backend);
  final RouterBackend backend;

  @override
  int get itemLimit => 128;

  @override
  Future<List<IpingCustomProxy>> read() async {
    final settings = await backend.readSettings();
    return [
      for (final item in settings['custom.proxies'] as List? ?? const [])
        IpingCustomProxy.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  @override
  Future<List<IpingCustomProxy>> write(List<IpingCustomProxy> items) async {
    validateIpingCustomProxies(items, limit: itemLimit);
    await backend.updateSettings({
      'custom.proxies': [for (final item in items) item.toJson()],
    });
    return read();
  }

  @override
  Future<String?> validate(IpingCustomProxy item) async {
    validateIpingCustomProxies([item]);
    final errors = await backend.client.call('validate_proxies', {
      'proxies': [item.definition],
    });
    if (errors is! List || errors.length != 1 || errors.single is! String) {
      throw const RouterException('invalid_response');
    }
    return (errors.single as String).isEmpty
        ? null
        : RouterException(errors.single as String).toString();
  }
}

class _RouterRuleProviders implements IpingResourceStore<IpingRuleProvider> {
  const _RouterRuleProviders(this.backend);
  final RouterBackend backend;

  @override
  int get itemLimit => 128;

  @override
  Future<List<IpingRuleProvider>> read() async {
    final settings = await backend.readSettings();
    return [
      for (final item in settings['custom.rule-providers'] as List? ?? const [])
        IpingRuleProvider.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  @override
  Future<List<IpingRuleProvider>> write(List<IpingRuleProvider> items) async {
    validateIpingRuleProviders(items, limit: itemLimit, remoteOnly: true);
    await backend.updateSettings({
      'custom.rule-providers': [for (final item in items) item.toJson()],
    });
    return read();
  }

  @override
  Future<String?> validate(IpingRuleProvider item) async {
    validateIpingRuleProviders([item], remoteOnly: true);
    return null;
  }
}

class _RouterAddedRules implements IpingResourceStore<IpingAddedRule> {
  const _RouterAddedRules(this.backend);
  final RouterBackend backend;
  @override
  int get itemLimit => 128;
  @override
  Future<List<IpingAddedRule>> read() async {
    final values = await backend.readSettings();
    return [
      for (final item in values['custom.rules'] as List? ?? const [])
        IpingAddedRule.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  @override
  Future<String?> validate(IpingAddedRule item) async {
    validateIpingAddedRules([item]);
    return null;
  }

  @override
  Future<List<IpingAddedRule>> write(List<IpingAddedRule> items) async {
    validateIpingAddedRules(items, limit: itemLimit);
    await backend.updateSettings({
      'custom.rules': [for (final item in items) item.toJson()],
    });
    return read();
  }
}

class _RouterScripts implements IpingResourceStore<IpingScript> {
  const _RouterScripts(this.backend);
  final RouterBackend backend;
  @override
  int get itemLimit => 128;
  @override
  Future<List<IpingScript>> read() async {
    final values = await backend.readSettings();
    return [
      for (final item in values['custom.scripts'] as List? ?? const [])
        IpingScript.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  @override
  Future<String?> validate(IpingScript item) async {
    validateIpingScripts([item]);
    final result = await backend.client.call('validate_scripts', {
      'scripts': [item.content],
    });
    if (result is! List || result.length != 1 || result.single is! String) {
      throw const RouterException('invalid_response');
    }
    return (result.single as String).isEmpty ? null : result.single as String;
  }

  @override
  Future<List<IpingScript>> write(List<IpingScript> items) async {
    validateIpingScripts(items, limit: itemLimit);
    await backend.updateSettings({
      'custom.scripts': [for (final item in items) item.toJson()],
    });
    return read();
  }
}
