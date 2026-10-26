import 'dart:io';
import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'providers.dart';
import 'site_config.dart';
import 'settings_native.dart';
import 'controller.dart';
import '../state.dart';
import '../common/service_probe.dart' as probes;
import '../providers/ip_quality.dart';

final ipingBackendProvider = Provider<IpingBackend>(
  (ref) => _NativeIpingBackend(ref),
);

final ipingClientControllerProvider = Provider<IpingController>((ref) {
  final controller = IpingController(
    ref.watch(ipingBackendProvider),
    refreshDetails: false,
    throwOnError: true,
    cancelSignInOnDispose: false,
    delayConcurrency: maxConcurrentDelayTests,
  );
  ref.listen(
    ipingBackendStateProvider,
    (_, next) => controller.receiveState(next),
    fireImmediately: true,
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final ipingBackendCapabilitiesProvider = Provider<Set<IpingBackendCapability>>(
  (ref) => system.isMobile
      ? const {IpingBackendCapability.vpn}
      : const {
          IpingBackendCapability.systemProxy,
          IpingBackendCapability.tun,
          IpingBackendCapability.tray,
        },
);

final ipingSettingsProvider = Provider<IpingSettings>(
  (ref) => nativeIpingSettings(
    ref.watch(patchClashConfigProvider),
    desktop: ref
        .watch(ipingBackendCapabilitiesProvider)
        .contains(IpingBackendCapability.tun),
  ),
);

final ipingModeProvider = Provider<Mode>(
  (ref) => ref.watch(patchClashConfigProvider.select((state) => state.mode)),
);

final ipingTrafficProvider = Provider<IpingTrafficSnapshot>((ref) {
  final history = ref.watch(trafficsProvider);
  return IpingTrafficSnapshot(
    samples: history.list,
    total: ref.watch(totalTrafficProvider),
    revision: history.revision,
    capacity: history.maxLength,
  );
});

final ipingBackendStateProvider = Provider<IpingBackendState>((ref) {
  final session = ref.watch(ipingSessionProvider);
  return IpingBackendState(
    initialized: session.initialized,
    signedIn: session.account != null,
    connected: ref.watch(isStartProvider),
    busy: session.busy,
    nodes: session.nodes,
    email: session.account?.email ?? '',
    site: ref.watch(ipingApiProvider).site,
    updated: session.updated,
  );
});

class _NativeIpingBackend implements IpingBackend {
  _NativeIpingBackend(this.ref);

  final Ref ref;

  @override
  Set<IpingResourceKind> get resourceKinds => const {
    IpingResourceKind.proxies,
    IpingResourceKind.ruleProviders,
    IpingResourceKind.filters,
    IpingResourceKind.rules,
    IpingResourceKind.scripts,
    IpingResourceKind.iconSets,
  };

  @override
  late final IpingResourceStore<Filter> filters = _NativeFilters(ref);

  @override
  late final IpingResourceStore<IpingCustomProxy> customProxies =
      _NativeCustomProxies(ref);

  @override
  late final IpingResourceStore<IpingRuleProvider> ruleProviders =
      _NativeRuleProviders(ref);

  @override
  late final IpingResourceStore<IpingAddedRule> addedRules = _NativeAddedRules(
    ref,
  );

  @override
  late final IpingResourceStore<IpingScript> scripts = _NativeScripts(ref);

  @override
  Future<IpingProfileResources> readProfileResources() async {
    final profile = ref.read(currentProfileProvider);
    return IpingProfileResources(
      profileId: profile?.id.toString() ?? '',
      label: profile?.realLabel ?? '',
      bindings: (profile?.overrides.resources ?? const IpingResourceBindings())
          .copyWith(
            script: profile?.extendType == ExtendType.script
                ? profile?.scriptId?.toString()
                : null,
          ),
    );
  }

  @override
  Future<void> updateProfileResources(IpingProfileResources value) async {
    final current = ref.read(currentProfileProvider);
    if (current == null || current.id.toString() != value.profileId) {
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
    if (ref.read(currentProfileProvider)?.id != current.id) {
      throw const IpingResourceException(IpingResourceIssue.missing);
    }
    final state = await ref.read(setupStateProvider(current.id).future);
    final message = await ref
        .read(setupActionProvider.notifier)
        .validateResourceBindings(
          state.copyWith(
            overrides: state.overrides.copyWith(
              resources: value.bindings.copyWith(script: null),
            ),
            extendType: value.bindings.script == null
                ? ExtendType.standard
                : ExtendType.script,
            script:
                (await ref.read(scriptsProvider.notifier).resourceSnapshot())
                    .where(
                      (item) => item.id.toString() == value.bindings.script,
                    )
                    .firstOrNull,
            addedRules: [
              for (final item
                  in await ref
                      .read(globalRulesProvider.notifier)
                      .resourceSnapshot())
                if (value.bindings.rules.contains(item.id.toString())) item,
              for (final item in state.addedRules)
                if (item.profileId != null) item,
            ],
            appProxies: await ref
                .read(customProxiesProvider.notifier)
                .resourceSnapshot(),
            clashProviders: await ref
                .read(clashProvidersProvider.notifier)
                .resourceSnapshot(),
            resourceFilters: [
              for (final item in presets)
                if (value.bindings.filters.contains(item.label)) item,
            ],
          ),
        );
    if (message.isNotEmpty) {
      throw IpingResourceException(
        IpingResourceIssue.invalid,
        message: message,
      );
    }
    if (ref.read(currentProfileProvider)?.id != current.id) {
      throw const IpingResourceException(IpingResourceIssue.missing);
    }
    await ref
        .read(profilesProvider.notifier)
        .setResourceBindings(current.id, value.bindings);
    if (ref.read(currentProfileProvider)?.id == current.id) {
      ref
          .read(setupActionProvider.notifier)
          .applyProfileDebounce(silence: true);
    }
  }

  @override
  Set<IpingBackendCapability> get capabilities =>
      ref.read(ipingBackendCapabilitiesProvider);

  @override
  Future<IpingBackendState> readState() async =>
      ref.read(ipingBackendStateProvider);

  @override
  Future<IpingSiteConfig> readSiteConfig() async {
    await ref.read(ipingSiteConfigProvider.notifier).refresh();
    return ref.read(ipingSiteConfigProvider);
  }

  @override
  Future<IpingUserInfo?> readAccount() =>
      ref.read(ipingUserInfoProvider.future);

  @override
  Future<RouteState> readProbeRoute() async => ref.read(routeTrackerProvider);

  @override
  Future<IpQuality> readIpQuality(String ip) =>
      ref.read(ipQualityProvider(ip).future);

  @override
  Future<ProbeAnswer<IpInfo>> lookupOutboundIp(String proxyName) async {
    final result = await probes.lookupOutboundIp(
      ref.read(coreHandlerProvider),
      proxyName,
    );
    return ProbeAnswer(
      value: probes.parseOutboundIp(result),
      coreEpoch: result?.coreEpoch,
      picksVersion: result?.picksVersion,
      chains: result?.chains ?? const [],
    );
  }

  @override
  Future<Map<ServiceTarget, ProbeAnswer<ServiceCheck>>> checkServices(
    String proxyName,
    List<ServiceTarget> targets,
  ) async {
    final checks = await probes.checkServices(
      ref.read(coreHandlerProvider),
      proxyName: proxyName,
      targets: targets,
    );
    return {
      for (final MapEntry(key: target, value: check) in checks.entries)
        target: ProbeAnswer(
          value: check,
          coreEpoch: check.coreEpoch,
          picksVersion: check.picksVersion,
          chains: check.chains,
        ),
    };
  }

  @override
  Future<IpingDashboardSnapshot> readDashboard() async {
    final counts = globalState.lastConfigCounts;
    final elapsed = ref.read(runTimeProvider);
    return IpingDashboardSnapshot(
      localIp: ref.read(localIpProvider) ?? '',
      started: !ref.read(isStartProvider) || elapsed == null
          ? null
          : DateTime.now().subtract(Duration(milliseconds: elapsed)),
      groups: counts?.groups ?? 0,
      proxies:
          (counts?.proxies ?? 0) +
          ref
              .read(providersProvider)
              .where((provider) => provider.type == 'Proxy')
              .fold<int>(0, (count, provider) => count + provider.count),
      rules: counts?.rules ?? 0,
      settings: readSettings(),
    );
  }

  @override
  Future<void> signIn({bool register = false}) => ref
      .read(ipingSessionProvider.notifier)
      .controller
      .signIn(register: register);

  @override
  void cancelSignIn() =>
      ref.read(ipingSessionProvider.notifier).controller.cancelSignIn();

  @override
  Future<void> synchronize() =>
      ref.read(ipingSessionProvider.notifier).synchronize();

  @override
  Future<bool> setConnected(bool connected) => ref
      .read(setupActionProvider.notifier)
      .setRunning(connected, initialize: connected && !ref.read(initProvider));

  @override
  Future<void> setMode(Mode mode) async {
    if (ref.read(ipingModeProvider) == mode) return;
    ref.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Future<IpingTelemetry> readTelemetry() async {
    final traffic = ref.read(ipingTrafficProvider);
    final mode = ref.read(ipingModeProvider);
    final connected = ref.read(coreStatusProvider) == CoreStatus.connected;
    if (!connected) return IpingTelemetry(traffic: traffic, mode: mode);
    final core = ref.read(coreHandlerProvider);
    final (connections, memory) = await (
      core.getConnectionCount(),
      core.getMemoryStats(),
    ).wait;
    return IpingTelemetry(
      traffic: traffic,
      mode: mode,
      connections: connections,
      memory: memory?.rss ?? 0,
    );
  }

  @override
  Future<void> signOut() =>
      ref.read(ipingSessionProvider.notifier).controller.signOut();

  @override
  IpingSettings readSettings() => ref.read(ipingSettingsProvider);

  @override
  Future<void> updateSettings(Map<String, Object?> changes) async {
    if (changes.isEmpty) return;
    ref
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => applyNativeIpingSettings(
            state,
            changes,
            desktop: capabilities.contains(IpingBackendCapability.tun),
          ),
        );
  }

  @override
  Future<IpingProxyPage> readProxies([
    IpingProxyQuery query = const IpingProxyQuery(),
  ]) => compute(_proxyPage, (
    groups: ref.read(groupsProvider),
    selected: ref.read(selectedMapProvider),
    delays: ref.read(delayDataSourceProvider),
    testUrl: ref.read(realTestUrlProvider()),
    mode: ref.read(patchClashConfigProvider).mode,
    query: query,
  ));

  @override
  Future<bool> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) => ref
      .read(proxiesActionProvider.notifier)
      .changeProxy(
        groupName: group,
        proxyName: name,
        closeConnections: closeConnections,
      );

  @override
  Future<Delay?> testDelay(String name, {required String url}) =>
      ref.read(coreHandlerProvider).getDelay(url, name);

  @override
  Future<IpingConnectionPage> readConnections([
    IpingConnectionQuery query = const IpingConnectionQuery(),
  ]) async {
    final items = await ref.read(coreHandlerProvider).getConnections();
    if (query.query.isEmpty && query.offset == 0 && query.limit == null) {
      return IpingConnectionPage(items: items, total: items.length);
    }
    return compute(_connectionPage, (items: items, query: query));
  }

  @override
  Future<int> readConnectionCount() =>
      ref.read(coreHandlerProvider).getConnectionCount();

  @override
  Future<void> closeConnection(String id) =>
      ref.read(coreHandlerProvider).closeConnection(id);

  @override
  Future<void> closeConnections() =>
      ref.read(coreHandlerProvider).closeConnections();

  @override
  IpingLogSnapshot readLogs() =>
      IpingLogSnapshot(logs: ref.read(logsProvider).list);
}

class _NativeFilters implements IpingResourceStore<Filter> {
  const _NativeFilters(this.ref);
  final Ref ref;

  @override
  int? get itemLimit => null;

  @override
  List<Filter> read() => ref.read(appSettingProvider).filters;

  @override
  Future<List<Filter>> write(List<Filter> items) async {
    await _validateNativeResources(items, validateIpingFilters);
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(filters: List.unmodifiable(items)));
    _applyBoundResources(ref, IpingResourceKind.filters);
    return read();
  }

  @override
  Future<String?> validate(Filter item) async {
    if (!isIpingFilterValid(item)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    try {
      final errors = await ref.read(coreHandlerProvider).validateFilters([
        item.regex,
      ]);
      return errors.single.isEmpty ? null : errors.single;
    } catch (error) {
      throw IpingResourceException(
        IpingResourceIssue.unavailable,
        message: compactError(error),
      );
    }
  }
}

typedef _ProxyPageInput = ({
  List<Group> groups,
  Map<String, String> selected,
  DelayMap delays,
  String testUrl,
  Mode mode,
  IpingProxyQuery query,
});

IpingProxyPage _proxyPage(_ProxyPageInput input) {
  final query = input.query;
  final search = SearchQuery(query.query);
  final summaries = <IpingProxyGroup>[];
  final members = <String, List<IpingProxyNode>>{};
  if (input.mode == Mode.direct) return const IpingProxyPage();
  for (final group in input.groups) {
    if (input.mode == Mode.rule && group.hidden == true) continue;
    final nodes = <IpingProxyNode>[];
    for (final node in group.all) {
      if (!search.matches(node.searchFields)) continue;
      final selected = computeRealSelectedProxyState(
        node.name,
        groups: input.groups,
        selectedMap: input.selected,
      );
      final testUrl = selected.testUrl.takeFirstValid([
        group.testUrl ?? '',
        input.testUrl,
      ]);
      nodes.add(
        IpingProxyNode(
          name: node.name,
          type: node.type,
          selected: node.now ?? '',
          delay: input.delays[testUrl]?[selected.proxyName],
        ),
      );
    }
    var visible = nodes;
    if (query.hideTimeout) {
      final available = nodes
          .where((node) => node.delay == null || node.delay! > 0)
          .toList();
      if (available.isNotEmpty) visible = available;
    }
    switch (query.sort) {
      case ProxiesSortType.none:
        break;
      case ProxiesSortType.name:
        visible.sort((a, b) => a.name.compareTo(b.name));
      case ProxiesSortType.delay:
        int rank(int? value) => value == null || value <= 0 ? 1 << 31 : value;
        visible.sort((a, b) => rank(a.delay).compareTo(rank(b.delay)));
    }
    final selected = group.getCurrentSelectedName(
      input.selected[group.name] ?? '',
    );
    summaries.add(
      IpingProxyGroup(
        name: group.name,
        type: group.type.name,
        count: visible.length,
        selected: selected,
        pinned: group.type.isComputedSelected
            ? input.selected[group.name] ?? ''
            : '',
        icon: group.icon,
        selectedIndex: visible.indexWhere((node) => node.name == selected),
      ),
    );
    members[group.name] = visible;
  }
  final group = query.group.isEmpty
      ? summaries.firstOrNull?.name ?? ''
      : query.group;
  final nodes = members[group] ?? const <IpingProxyNode>[];
  final offset = query.offset < 0 || query.offset > nodes.length
      ? 0
      : query.offset;
  return IpingProxyPage(
    groups: summaries,
    group: group,
    items: nodes.skip(offset).take(ipingBackendPageSize).toList(),
    total: nodes.length,
    offset: offset,
    selectedIndex:
        summaries
            .where((item) => item.name == group)
            .firstOrNull
            ?.selectedIndex ??
        -1,
  );
}

IpingConnectionPage _connectionPage(
  ({List<TrackerInfo> items, IpingConnectionQuery query}) input,
) {
  final search = SearchQuery(input.query.query);
  final items =
      input.items.where((item) => search.matches(item.searchFields)).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
  final offset = input.query.offset < 0 || input.query.offset > items.length
      ? 0
      : input.query.offset;
  final remaining = items.skip(offset);
  return IpingConnectionPage(
    items:
        (input.query.limit == null
                ? remaining
                : remaining.take(input.query.limit!))
            .toList(),
    total: items.length,
    offset: offset,
  );
}

IpingCustomProxy nativeIpingCustomProxy(CustomProxy proxy) => IpingCustomProxy(
  id: proxy.id.toString(),
  definition: proxy.definition,
  emptyOptions: proxy.emptyOptions.map((field) => field.name),
);

IpingRuleProvider nativeIpingRuleProvider(ClashProvider provider) =>
    IpingRuleProvider(
      id: provider.id.toString(),
      label: provider.label,
      url: provider.url,
      behavior: provider.behavior.name,
      format: provider.format.name,
    );

class _NativeCustomProxies implements IpingResourceStore<IpingCustomProxy> {
  _NativeCustomProxies(this.ref) {
    ref.listen(customProxiesProvider, (_, _) {});
  }
  final Ref ref;

  @override
  int? get itemLimit => null;

  Future<List<CustomProxy>> _read() =>
      ref.read(customProxiesProvider.notifier).resourceSnapshot();

  @override
  Future<List<IpingCustomProxy>> read() async {
    final items = await _read();
    return items.length > 32
        ? compute(_nativeProxyResources, items)
        : _nativeProxyResources(items);
  }

  @override
  Future<String?> validate(IpingCustomProxy item) async {
    validateIpingCustomProxies([item]);
    try {
      final errors = await ref.read(coreHandlerProvider).validateProxies([
        item.definition,
      ]);
      return errors.single.isEmpty ? null : errors.single;
    } catch (error) {
      throw IpingResourceException(
        IpingResourceIssue.unavailable,
        message: compactError(error),
      );
    }
  }

  @override
  Future<List<IpingCustomProxy>> write(List<IpingCustomProxy> items) async {
    await _validateNativeResources(items, validateIpingCustomProxies);
    final previous = await _read();
    final byId = {for (final item in previous) item.id.toString(): item};
    final next = [
      for (final item in items)
        CustomProxy(
          id: byId[item.id]?.id ?? int.tryParse(item.id) ?? snowflake.id,
          order: byId[item.id]?.order,
          definition: Map<String, dynamic>.from(item.definition),
          emptyOptions: {
            for (final name in item.emptyOptions)
              ProxyField.values.byName(name),
          },
        ),
    ];
    final notifier = ref.read(customProxiesProvider.notifier);
    for (final item in next) {
      if (byId[item.id.toString()] != item) await notifier.putAsync(item);
    }
    final ids = {for (final item in next) item.id};
    final removed = previous.where((item) => !ids.contains(item.id));
    if (removed.isNotEmpty) {
      await notifier.delAllAsync(removed.map((item) => item.id));
    }
    final current = await _read();
    if (!const ListEquality<int>().equals(
      current.map((item) => item.id).toList(),
      next.map((item) => item.id).toList(),
    )) {
      final latest = {for (final item in current) item.id: item};
      await notifier.setAllAsync([
        for (final item in next) latest[item.id]!,
        for (final item in current)
          if (!ids.contains(item.id) && !byId.containsKey(item.id.toString()))
            item,
      ]);
    }
    _applyBoundResources(ref, IpingResourceKind.proxies);
    return read();
  }
}

class _NativeRuleProviders implements IpingResourceStore<IpingRuleProvider> {
  _NativeRuleProviders(this.ref) {
    ref.listen(clashProvidersProvider, (_, _) {});
  }
  final Ref ref;

  @override
  int? get itemLimit => null;

  Future<List<ClashProvider>> _read() =>
      ref.read(clashProvidersProvider.notifier).resourceSnapshot();

  @override
  Future<List<IpingRuleProvider>> read() async =>
      (await _read()).map(nativeIpingRuleProvider).toList();

  @override
  Future<String?> validate(IpingRuleProvider item) async {
    validateIpingRuleProviders([item]);
    return null;
  }

  @override
  Future<List<IpingRuleProvider>> write(List<IpingRuleProvider> items) async {
    await _validateNativeResources(items, validateIpingRuleProviders);
    final previous = await _read();
    final byId = {for (final item in previous) item.id.toString(): item};
    final action = ref.read(clashProvidersActionProvider.notifier);
    final ids = <int>[];
    for (final item in items) {
      final stored = byId[item.id];
      if (stored == null && !item.isRemote) {
        throw const IpingResourceException(IpingResourceIssue.invalid);
      }
      final next = ClashProvider(
        id: stored?.id ?? int.tryParse(item.id) ?? snowflake.id,
        order: stored?.order,
        label: item.label,
        url: item.url,
        behavior: RuleProviderBehavior.values.byName(item.behavior),
        format: RuleProviderFormat.values.byName(item.format),
      );
      if (stored != next) await action.putProvider(next, previous: stored);
      ids.add(next.id);
    }
    for (final item in previous) {
      if (!ids.contains(item.id)) await action.delProviderAsync(item);
    }
    final current = await _read();
    if (!const ListEquality<int>().equals(
      current.map((item) => item.id).toList(),
      ids,
    )) {
      await ref.read(clashProvidersProvider.notifier).orderResources(ids);
    }
    _applyBoundResources(ref, IpingResourceKind.ruleProviders);
    return read();
  }
}

List<IpingCustomProxy> _nativeProxyResources(List<CustomProxy> items) =>
    items.map(nativeIpingCustomProxy).toList();

Future<void> _validateNativeResources<T>(
  List<T> items,
  void Function(List<T>) validate,
) async {
  if (items.length > 32) {
    await compute(validate, items);
  } else {
    validate(items);
  }
}

void _applyBoundResources(Ref ref, IpingResourceKind kind) {
  final profile = ref.read(currentProfileProvider);
  if (profile == null) return;
  final bindings = profile.overrides.resources;
  final selected = switch (kind) {
    IpingResourceKind.proxies => bindings.proxies,
    IpingResourceKind.ruleProviders => bindings.providers,
    IpingResourceKind.filters => bindings.filters,
    IpingResourceKind.rules => bindings.rules,
    IpingResourceKind.scripts =>
      profile.extendType == ExtendType.script && profile.scriptId != null
          ? {profile.scriptId!.toString()}
          : const <String>{},
    _ => const <String>{},
  };
  if (selected.isEmpty) return;
  ref.invalidate(setupStateProvider(profile.id));
  ref.read(setupActionProvider.notifier).applyProfileDebounce(silence: true);
}

class _NativeAddedRules implements IpingResourceStore<IpingAddedRule> {
  _NativeAddedRules(this.ref) {
    ref.listen(globalRulesProvider, (_, _) {});
  }
  final Ref ref;
  @override
  int? get itemLimit => null;
  @override
  Future<List<IpingAddedRule>> read() async => [
    for (final item
        in await ref.read(globalRulesProvider.notifier).resourceSnapshot())
      IpingAddedRule(id: item.id.toString(), rule: item),
  ];
  @override
  Future<String?> validate(IpingAddedRule item) async {
    validateIpingAddedRules([item]);
    return null;
  }

  @override
  Future<List<IpingAddedRule>> write(List<IpingAddedRule> items) async {
    await _validateNativeResources(items, validateIpingAddedRules);
    final previous = await ref
        .read(globalRulesProvider.notifier)
        .resourceSnapshot();
    final byId = {for (final item in previous) item.id.toString(): item};
    await ref.read(globalRulesProvider.notifier).writeResources([
      for (final item in items)
        item.rule.copyWith(
          id: byId[item.id]?.id ?? int.tryParse(item.id) ?? snowflake.id,
          order: byId[item.id]?.order,
        ),
    ]);
    _applyBoundResources(ref, IpingResourceKind.rules);
    return read();
  }
}

class _NativeScripts implements IpingResourceStore<IpingScript> {
  _NativeScripts(this.ref) {
    ref.listen(scriptsProvider, (_, _) {});
  }
  final Ref ref;
  @override
  int? get itemLimit => null;
  @override
  Future<List<IpingScript>> read() async {
    final scripts = await ref.read(scriptsProvider.notifier).resourceSnapshot();
    if (scripts.isEmpty) return const [];
    return compute(_nativeScriptResources, (
      scripts: scripts,
      directory: await appPath.scriptsDirPath,
    ));
  }

  @override
  Future<String?> validate(IpingScript item) async {
    validateIpingScripts([item]);
    try {
      await validateScriptSyntax(item.content);
      return null;
    } catch (error) {
      return compactError(error);
    }
  }

  @override
  Future<List<IpingScript>> write(List<IpingScript> items) async {
    await _validateNativeResources(items, validateIpingScripts);
    final previous = await ref
        .read(scriptsProvider.notifier)
        .resourceSnapshot();
    final byId = {for (final item in previous) item.id.toString(): item};
    final next = <Script>[];
    final action = ref.read(scriptsActionProvider.notifier);
    for (final item in items) {
      final old = byId[item.id];
      var script = (old ?? Script.create(label: item.label, url: item.url))
          .copyWith(label: item.label, url: item.url);
      if (old == null ||
          old.label != item.label ||
          old.url != item.url ||
          (await old.content ?? '') != item.content) {
        script = await action.saveScript(script, item.content);
      }
      next.add(script);
    }
    for (final item in previous) {
      if (!next.any((value) => value.id == item.id)) {
        await action.delScript(item);
      }
    }
    final current = await ref.read(scriptsProvider.notifier).resourceSnapshot();
    if (!const ListEquality<int>().equals(
      current.map((item) => item.id).toList(),
      next.map((item) => item.id).toList(),
    )) {
      await ref.read(scriptsProvider.notifier).orderResources([
        for (final item in next) item.id,
      ]);
    }
    _applyBoundResources(ref, IpingResourceKind.scripts);
    return read();
  }
}

List<IpingScript> _nativeScriptResources(
  ({List<Script> scripts, String directory}) input,
) {
  final directory = Directory(input.directory).uri;
  return [
    for (final item in input.scripts)
      IpingScript(
        id: item.id.toString(),
        label: item.label,
        url: item.url,
        content: _readScriptResource(
          File.fromUri(directory.resolve(item.fileName)),
        ),
      ),
  ];
}

String _readScriptResource(File file) =>
    file.existsSync() ? file.readAsStringSync() : '';
