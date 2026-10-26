import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/ui/group_monogram.dart';
import 'package:fl_clash/ui/proxy_style.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/proxies/list_presentation.dart';
import 'package:fl_clash/views/proxies/page_presentation.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

class _RemoteGroup {
  _RemoteGroup(this.name)
    : metadata = IpingProxyGroup(name: name, type: '', count: 0);
  final String name;
  IpingProxyGroup metadata;
  final items = <int, IpingProxyNode>{};
  final loading = <int>{};
  final errors = <int, String>{};
  final scroll = ScrollController();
  int count = 0;
  int selectedIndex = -1;
  int revision = 0;
  double paneWidth = 0;
  bool expanded = true;
}

class RouterProxies extends StatefulWidget {
  const RouterProxies({super.key});
  @override
  State<RouterProxies> createState() => _RouterProxiesState();
}

class _RouterProxiesState extends State<RouterProxies>
    with TickerProviderStateMixin {
  final _groups = <String, _RemoteGroup>{};
  TabController? _tabs;
  Timer? _searchTimer;
  ProxyViewPreferences _preferences = const ProxyViewPreferences();
  String _query = '';
  int _generation = 0;
  (int, int, int)? _seenRevision;
  bool _loading = false;
  bool _resetPending = false;
  String? _testingGroup;
  bool _wasConnected = false;
  bool _preferencesLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = RouterScope.of(context, aspect: RouterAspect.proxies);
    RouterScope.of(context, aspect: RouterAspect.status);
    if (!_preferencesLoaded) {
      _preferencesLoaded = true;
      _preferences = RouterAppState.of(context).preferences.proxies;
    }
    final revision = (
      router.revision,
      router.probes.outbound.route.coreEpoch,
      router.probes.outbound.route.picksVersion,
    );
    if (router.connected &&
        (!_wasConnected ||
            (_seenRevision != revision &&
                PageActivityScope.isActiveOf(context)))) {
      _seenRevision = revision;
      unawaited(_load());
    }
    _wasConnected = router.connected;
  }

  IpingProxyQuery _args(String group, int offset) => IpingProxyQuery(
    group: group,
    offset: offset,
    query: _query,
    sort: _preferences.sort,
    hideTimeout: _preferences.hideTimeout,
  );

  void _applyPage(_RemoteGroup group, IpingProxyPage page) {
    for (var index = 0; index < page.items.length; index++) {
      group.items[page.offset + index] = page.items[index];
    }
    group.count = page.total;
    group.selectedIndex = page.selectedIndex;
    group.revision++;
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _generation++;
      _resetPending = true;
    }
    if (_loading || !mounted) return;
    final router = RouterScope.read(context);
    if (!router.connected || router.busy) return;
    _loading = true;
    final generation = _generation;
    final resetting = _resetPending;
    _resetPending = false;
    try {
      final data = await router.backend.readProxies(_args('', 0));
      if (!mounted || generation != _generation) return;
      final previous = _groups.keys.toList();
      final selectedName = previous.isEmpty
          ? null
          : previous[_tabs?.index.clamp(0, previous.length - 1) ?? 0];
      final names = <String>[];
      for (final metadata in data.groups) {
        final name = metadata.name;
        final group = _groups.putIfAbsent(name, () => _RemoteGroup(name));
        group.metadata = metadata;
        group.count = metadata.count;
        group.selectedIndex = metadata.selectedIndex;
        if (resetting) {
          group.items.clear();
          group.errors.clear();
          group.loading.clear();
          group.revision++;
        }
        names.add(name);
      }
      final first = _groups[data.group];
      if (first != null) _applyPage(first, data);
      final oldNames =
          _tabs?.length == names.length &&
          previous.join('\u0000') == names.join('\u0000');
      if (!oldNames || _tabs == null) {
        _tabs?.dispose();
        _tabs = names.isEmpty
            ? null
            : TabController(
                length: names.length,
                initialIndex: math.max(names.indexOf(selectedName ?? ''), 0),
                vsync: this,
              );
      }
      for (final name
          in _groups.keys.where((name) => !names.contains(name)).toList()) {
        _groups.remove(name)?.scroll.dispose();
      }
      final ordered = {for (final name in names) name: _groups[name]!};
      _groups
        ..clear()
        ..addAll(ordered);
      setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(routerError(context, error.toString()))),
        );
      }
    } finally {
      _loading = false;
      if (_resetPending && mounted) unawaited(_load());
    }
  }

  Future<void> _page(
    _RemoteGroup group,
    int index, {
    bool retry = false,
  }) async {
    final offset = index ~/ ipingBackendPageSize * ipingBackendPageSize;
    if (group.loading.contains(offset) ||
        (!retry && group.errors.containsKey(offset))) {
      return;
    }
    final generation = _generation;
    group.loading.add(offset);
    try {
      final page = await RouterScope.of(
        context,
      ).backend.readProxies(_args(group.name, offset));
      if (!mounted || generation != _generation) return;
      setState(() {
        _applyPage(group, page);
        group.errors.remove(offset);
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          group.errors[offset] = error.toString();
          group.revision++;
        });
      }
    } finally {
      if (generation == _generation) group.loading.remove(offset);
    }
  }

  Future<void> _select(_RemoteGroup group, String name) async {
    final router = RouterScope.read(context);
    final selection = group.metadata.selectionFor(name);
    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).notSelectedTip)),
      );
      return;
    }
    await router.selectProxy(
      group.name,
      selection,
      closeConnections: RouterAppState.of(context).preferences.closeConnections,
    );
    if (mounted) await _load();
  }

  Future<void> _test(_RemoteGroup group) async {
    if (_testingGroup != null) return;
    final router = RouterScope.read(context);
    final testUrl = RouterAppState.of(context).preferences.testUrl;
    setState(() => _testingGroup = group.name);
    try {
      for (
        var offset = 0;
        offset < group.count && mounted;
        offset += ipingBackendPageSize
      ) {
        if (!group.items.containsKey(offset)) {
          await _page(group, offset, retry: true);
          if (!mounted) return;
        }
        final names = [
          for (
            var index = offset;
            index < math.min(offset + ipingBackendPageSize, group.count);
            index++
          )
            if (group.items[index]?.name case final String name) name,
        ];
        if (!await router.testDelays(names, url: testUrl)) {
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _testingGroup = null);
    }
  }

  Widget _node(BuildContext context, _RemoteGroup group, int index) {
    final item = group.items[index];
    if (item == null) {
      unawaited(_page(group, index));
      return ProxyNodePending(
        error:
            group.errors[index ~/ ipingBackendPageSize * ipingBackendPageSize],
        onRetry: () => _page(group, index, retry: true),
      );
    }
    final router = RouterScope.read(context);
    final l = AppLocalizations.of(context);
    final name = item.name;
    final testUrl = RouterAppState.of(context).preferences.testUrl;
    final delay = router.delayFor(name, testUrl) ?? item.delay;
    final type = item.type;
    final actual = item.selected;
    return ProxyNodeCard(
      name: name,
      description:
          _preferences.card == ProxyCardType.loose &&
              actual.isNotEmpty &&
              actual != name
          ? '$type($actual)'
          : type,
      compact: _preferences.card == ProxyCardType.compact,
      loose: _preferences.card == ProxyCardType.loose,
      inUse: group.metadata.selected == name,
      pinned: group.metadata.pinned == name,
      latency: ProxyLatency(
        delay: delay,
        phase: router.isTestingDelay(name, testUrl)
            ? (router.isRunningDelay(name, testUrl)
                  ? ProxyLatencyPhase.running
                  : ProxyLatencyPhase.queued)
            : null,
        alignment: _preferences.card == ProxyCardType.loose
            ? Alignment.centerLeft
            : Alignment.centerRight,
        tooltip: l.delayTest,
        failureText: delay == -1 ? l.timeout : l.delayFailed,
        onPressed: () => router.testDelay(
          name,
          url: RouterAppState.of(context).preferences.testUrl,
        ),
      ),
      onPressed: router.busy ? null : () => _select(group, name),
    );
  }

  double _height(BuildContext context) => proxyCardHeight(
    MeasureScope.of(context),
    compact: _preferences.card == ProxyCardType.compact,
    loose: _preferences.card == ProxyCardType.loose,
  );

  void _settings() {
    showSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => CommonScaffold(
          title: AppLocalizations.of(context).settings,
          body: ProxiesSettingsBody(
            value: _preferences,
            onChanged: (value) {
              setState(() => _preferences = value);
              RouterAppState.of(
                this.context,
              ).updatePreferences((settings) => settings.proxies = value);
              update(() {});
              unawaited(_load(reset: true));
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = RouterScope.read(context);
    final groups = router.connected
        ? _groups.values.toList()
        : <_RemoteGroup>[];
    final current = groups.isEmpty
        ? null
        : groups[_tabs?.index.clamp(0, groups.length - 1) ?? 0];
    return ProxiesPage(
      loading: _loading,
      tabMode: _preferences.type == ProxiesType.tab,
      testing: _testingGroup != null,
      onSearch: (query) {
        _searchTimer?.cancel();
        _searchTimer = Timer(const Duration(milliseconds: 250), () {
          _query = query;
          unawaited(_load(reset: true));
        });
      },
      onTest: current == null ? null : () => _test(current),
      onLocate: current == null
          ? null
          : () {
              final index = current.selectedIndex;
              if (index < 0) return;
              final columns = proxyColumns(
                math.max(current.paneWidth - 32, 0),
                _preferences.layout,
              );
              animateProxyScrollTo(
                current.scroll,
                index ~/ columns * (_height(context) + 8),
              );
            },
      onSettings: _settings,
      body: _preferences.type == ProxiesType.list
          ? ProxyGroupsList(
              itemHeight: _height(context),
              layout: _preferences.layout,
              iconStyle: _preferences.icon,
              searching: _query.isNotEmpty,
              gap: context.isMobileView
                  ? 8
                  : MediaQuery.sizeOf(context).width <= 840
                  ? 12
                  : 16,
              groups: [
                for (final group in groups)
                  if (group.count > 0)
                    ProxyGroupPresentation(
                      name: group.name,
                      type: group.metadata.type,
                      count: group.count,
                      identity: (group.name, group.revision),
                      expanded: group.expanded,
                      selectedName: group.metadata.selected,
                      testing: _testingGroup == group.name,
                      selectedIndex: () =>
                          group.selectedIndex < 0 ? null : group.selectedIndex,
                      itemBuilder: (context, index) =>
                          _node(context, group, index),
                      iconBuilder: (_) => group.metadata.icon.isNotEmpty
                          ? Image.network(
                              group.metadata.icon,
                              width: 24,
                              height: 24,
                              errorBuilder: (_, error, stack) =>
                                  GroupMonogram(group.name),
                            )
                          : GroupMonogram(group.name),
                      onToggle: () =>
                          setState(() => group.expanded = !group.expanded),
                      onTest: () => _test(group),
                    ),
              ],
            )
          : _tabs == null
          ? const SizedBox.shrink()
          : ProxyTabsLayout(
              controller: _tabs!,
              groups: [for (final group in groups) group.name],
              pages: [
                for (final group in groups)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      group.paneWidth = constraints.maxWidth;
                      return ProxyCardsGrid(
                        controller: group.scroll,
                        columns: proxyColumns(
                          math.max(constraints.maxWidth - 32, 0),
                          _preferences.layout,
                        ),
                        itemHeight: _height(context),
                        count: group.count,
                        itemBuilder: (context, index) =>
                            _node(context, group, index),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _tabs?.dispose();
    _searchTimer?.cancel();
    for (final group in _groups.values) {
      group.scroll.dispose();
    }
    super.dispose();
  }
}
