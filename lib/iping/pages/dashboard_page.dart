import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/datetime.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/dashboard_defaults.dart';
import 'package:fl_clash/iping/widgets/dashboard_card_editor.dart';
import 'package:fl_clash/iping/widgets/network_takeover.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/desktop_layout.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/panel_layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/intranet_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_summary.dart';
import 'package:fl_clash/views/dashboard/widgets/mode_control.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_content.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/proxy_groups_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/record_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/record_table.dart';
import 'package:fl_clash/views/dashboard/widgets/service_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../dashboard_host.dart';

List<ServiceTarget> _serviceTargets(IpingDashboardPreferences preferences) =>
    enabledServices(
      orderServiceTargets(preferences.serviceOrder),
      preferences.disabledServices,
    );

IpingDashboardDesktopCard? _desktopPlacementOf(
  List<IpingDashboardCard> cards,
  IpingDashboardDesktopArea area, {
  String? cardId,
}) {
  for (final card in cards) {
    if (cardId != null && card.id != cardId) continue;
    for (final placement in card.desktop) {
      if (placement.area == area) return placement;
    }
  }
  return null;
}

List<(int, Widget)> _desktopSlotsOf(
  BuildContext context,
  List<IpingDashboardCard> cards,
  IpingDashboardDesktopArea area,
) => [
  for (final card in cards)
    for (final placement in card.desktop)
      if (placement.area == area) (placement.span, placement.builder(context)),
];

Widget _desktopTablesOf(
  BuildContext context,
  List<IpingDashboardCard> cards, {
  required double gap,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: gap,
  children: [
    for (final (span, widget) in _desktopSlotsOf(
      context,
      cards,
      IpingDashboardDesktopArea.table,
    ))
      Expanded(flex: span, child: widget),
  ],
);

class IpingDashboardPage extends StatefulWidget {
  const IpingDashboardPage({super.key});

  @override
  State<IpingDashboardPage> createState() => _IpingDashboardPageState();
}

class _IpingDashboardPageState extends State<IpingDashboardPage>
    with RouteMotionHoldMixin {
  Timer? _timer;
  bool _loading = false;
  List<TrackerInfo> _connections = [];
  List<IpingProxyGroup> _groups = [];
  IpingDashboardSnapshot? _snapshot;
  IpingDashboardProbes? _probes;
  Set<ServiceTarget> _watchedServices = {};
  final _cardKeys = <String, GlobalKey>{};
  bool _editing = false;

  GlobalKey _cardKeyOf(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  void _startEditing() => setState(() => _editing = true);

  void _stopEditing() {
    if (_editing) setState(() => _editing = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = IpingDashboardScope.of(context);
    // A host that brings its own cards owns their probes and data.
    if (host.dashboardEditor != null) return;
    final probes = host.probes;
    if (!identical(probes, _probes)) {
      _probes?.outbound.unwatch('');
      for (final target in _watchedServices) {
        _probes?.services.unwatch(target);
      }
      _probes = probes;
      _watchedServices = {};
      probes.outbound.watch('');
    }
    final targets = _serviceTargets(host.preferences).take(4).toSet();
    for (final target in targets.difference(_watchedServices)) {
      probes.services.watch(target);
    }
    for (final target in _watchedServices.difference(targets)) {
      probes.services.unwatch(target);
    }
    _watchedServices = targets;
    if (_timer != null) return;
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && PageActivityScope.isActiveOf(context)) {
        unawaited(_load());
      }
    });
  }

  Future<void> _load() async {
    final host = IpingDashboardScope.read(context);
    if (host.dashboardEditor != null ||
        _loading ||
        !host.hasSubscription ||
        !host.visible ||
        host.busy) {
      return;
    }
    _loading = true;
    final tables = !context.isMobileView;
    try {
      final (snapshot, connections, proxies) = await (
        host.readDashboard(),
        tables && host.connected
            ? host.backend.readConnections()
            : Future.value(const IpingConnectionPage()),
        tables && host.connected
            ? host.backend.readProxies()
            : Future.value(const IpingProxyPage()),
      ).wait;
      if (!mounted) return;
      updateWhenRouteSettled(() {
        if (!mounted) return;
        final previous = _snapshot;
        if (tables ||
            previous == null ||
            previous.localIp != snapshot.localIp ||
            previous.started != snapshot.started ||
            previous.groups != snapshot.groups ||
            previous.proxies != snapshot.proxies ||
            previous.rules != snapshot.rules ||
            !mapEquals(previous.settings.values, snapshot.settings.values)) {
          setState(() {
            _snapshot = snapshot;
            _connections = connections.items;
            _groups = proxies.groups;
          });
        }
      });
    } catch (_) {
      if (mounted && (_connections.isNotEmpty || _groups.isNotEmpty)) {
        setState(() {
          _connections = [];
          _groups = [];
        });
      }
    } finally {
      _loading = false;
    }
  }

  bool get _dragsAtOnce => switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final host = IpingDashboardScope.of(context);
    final hostEditor = host.dashboardEditor;
    final savedCards = host.dashboardCards;
    final defaultEditor = hostEditor == null
        ? IpingDashboardDefaultEditor(
            all: _defaultCards(context, host: host, l: l),
            defaultIds: _defaultCardIds,
            saved: savedCards ?? const [],
            onSave: savedCards == null ? null : host.saveDashboardCards,
          )
        : null;
    final editor = hostEditor ?? defaultEditor!;
    final canEdit = hostEditor != null || savedCards != null;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    return LayoutBuilder(
      builder: (context, page) {
        final editable = canEdit && dashboardIsMobileOf(page.maxWidth / scale);
        if (!editable) _editing = false;
        final editing = _editing;
        return CommonScaffold(
          backgroundColor: DashboardColors.of(context).page,
          title: editing ? l.editDashboard : l.dashboard,
          backAction: editing ? _stopEditing : null,
          actions: [
            if (hostEditor == null)
              FilledButton.icon(
                style: ElasticPress.buttonStyle,
                onPressed: host.busy ? null : () => _restart(context),
                icon: host.busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CommonCircleLoading(size: 16),
                      )
                    : GlyphIcon(
                        host.connected ? AppGlyphs.check : AppGlyphs.close,
                        fill: 1,
                      ),
                label: Text(host.connected ? l.running : l.notRunning),
              ),
          ],
          confirmationAction: editing
              ? IconButtonData(
                  glyph: AppGlyphs.check,
                  tooltip: l.done,
                  onPressed: _stopEditing,
                )
              : null,
          iconActions: [
            if (editable && !editing)
              IconButtonData(
                glyph: AppGlyphs.edit,
                tooltip: l.editDashboard,
                onPressed: _startEditing,
              ),
            if (editing)
              IconButtonData(
                glyph: AppGlyphs.reset,
                tooltip: l.reset,
                onPressed: editor.reset,
              ),
          ],
          body: Builder(
            builder: (context) => LayoutBuilder(
              builder: (context, constraints) {
                final density = DashboardDensity.of(
                  constraints.biggest / scale,
                );
                final gap = density.isDesktop
                    ? (MediaQuery.sizeOf(context).width <= 840 ? 12.0 : 16.0)
                    : 8.0;
                final bottomInset = BottomInsetScope.of(context);
                return DashboardDensityScope(
                  density: density,
                  scale: scale,
                  child: density.isDesktop
                      ? (hostEditor == null
                            ? _buildDefaultDesktop(
                                context,
                                defaultEditor!,
                                constraints,
                                density: density,
                                gap: gap,
                                scale: scale,
                              )
                            : _buildHostDesktop(
                                context,
                                hostEditor,
                                constraints,
                                density: density,
                                gap: gap,
                                scale: scale,
                              ))
                      : _buildHostMobile(
                          context,
                          editor,
                          constraints,
                          gap: gap,
                          bottomInset: bottomInset,
                          editing: editing,
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHostMobile(
    BuildContext context,
    IpingDashboardEditor editor,
    BoxConstraints constraints, {
    required double gap,
    required double bottomInset,
    required bool editing,
  }) {
    final top = MediaQuery.paddingOf(context).top + 4;
    final bottom = 16 + bottomInset;
    final side = dashboardMobileSideOf(constraints.maxWidth);
    if (editing) {
      return CustomScrollView(
        scrollCacheExtent: ScrollCacheExtent.viewport(
          (editor.cards.length + editor.available.length).toDouble(),
        ),
        slivers: [
          IpingDashboardCardEditor(
            cards: editor.cards,
            available: editor.available,
            cardKeyOf: _cardKeyOf,
            padding: EdgeInsets.fromLTRB(side, top, side, bottom),
            gap: gap,
            onDone: _stopEditing,
            onSave: editor.save,
            dragsAtOnce: _dragsAtOnce,
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          sliver: SliverToBoxAdapter(
            child: Column(
              spacing: gap,
              children: [
                for (final card in editor.cards)
                  RepaintBoundary(
                    key: _cardKeyOf(card.id),
                    child: card.builder(context),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostDesktop(
    BuildContext context,
    IpingDashboardEditor editor,
    BoxConstraints constraints, {
    required DashboardDensity density,
    required double gap,
    required double scale,
  }) {
    final cards = editor.desktopCards;
    final tables = _desktopSlotsOf(
      context,
      cards,
      IpingDashboardDesktopArea.table,
    );
    return DashboardDesktopLayout(
      columns: dashboardColumnsOf(constraints.maxWidth / scale),
      gap: gap,
      outbound:
          _desktopPlacementOf(
            cards,
            IpingDashboardDesktopArea.outbound,
          )?.builder(context) ??
          const SizedBox.shrink(),
      upload:
          _desktopPlacementOf(
            cards,
            IpingDashboardDesktopArea.upload,
          )?.builder(context) ??
          const SizedBox.shrink(),
      download:
          _desktopPlacementOf(
            cards,
            IpingDashboardDesktopArea.download,
          )?.builder(context) ??
          const SizedBox.shrink(),
      mode:
          _desktopPlacementOf(
            cards,
            IpingDashboardDesktopArea.mode,
          )?.builder(context) ??
          const SizedBox.shrink(),
      controls: _desktopSlotsOf(
        context,
        cards,
        IpingDashboardDesktopArea.control,
      ),
      middle: _desktopSlotsOf(context, cards, IpingDashboardDesktopArea.middle),
      summaries: [
        for (final (_, widget) in _desktopSlotsOf(
          context,
          cards,
          IpingDashboardDesktopArea.summary,
        ))
          widget,
      ],
      tables: tables.isEmpty
          ? null
          : _desktopTablesOf(context, cards, gap: gap),
      tablesMinHeight: connectionsTableMinHeight(density, scale),
    );
  }

  Widget _buildDefaultDesktop(
    BuildContext context,
    IpingDashboardEditor editor,
    BoxConstraints constraints, {
    required DashboardDensity density,
    required double gap,
    required double scale,
  }) {
    final cards = editor.desktopCards;
    Widget slot(IpingDashboardDesktopArea area, {String? id}) =>
        _desktopPlacementOf(cards, area, cardId: id)?.builder(context) ??
        const SizedBox.shrink();
    final tables = _desktopSlotsOf(
      context,
      cards,
      IpingDashboardDesktopArea.table,
    );
    return DashboardPanelLayout(
      columns: dashboardColumnsOf(constraints.maxWidth / scale),
      gap: gap,
      outbound: slot(IpingDashboardDesktopArea.outbound),
      upload: slot(IpingDashboardDesktopArea.upload),
      download: slot(IpingDashboardDesktopArea.download),
      mode: slot(IpingDashboardDesktopArea.mode),
      controls: _desktopSlotsOf(
        context,
        cards,
        IpingDashboardDesktopArea.control,
      ),
      intranet: slot(IpingDashboardDesktopArea.middle, id: 'intranet'),
      profile: slot(IpingDashboardDesktopArea.middle, id: 'profile'),
      services: slot(IpingDashboardDesktopArea.middle, id: 'services'),
      memory: slot(IpingDashboardDesktopArea.middle, id: 'memory'),
      summaries: [
        for (final (_, widget) in _desktopSlotsOf(
          context,
          cards,
          IpingDashboardDesktopArea.summary,
        ))
          widget,
      ],
      tablesMinHeight: connectionsTableMinHeight(density, scale),
      tables: tables.isEmpty
          ? const SizedBox.shrink()
          : _desktopTablesOf(context, cards, gap: gap),
    );
  }

  static const _defaultCardIds = [
    'currentOutbound',
    'networkSpeed',
    'outboundMode',
    'networkTakeover',
    'profile',
    'intranet',
    'services',
    'connections',
    'memory',
  ];

  List<IpingDashboardCard> _defaultCards(
    BuildContext context, {
    required IpingDashboardHost host,
    required AppLocalizations l,
  }) {
    final status = _ConnectionCard(host: host, snapshot: _snapshot);
    final upload = _SpeedCard(host: host, upload: true);
    final download = _SpeedCard(host: host, upload: false);
    final mode = _ModeCard(host: host);
    final systemProxy = host.networkTakeover.supportsSystemProxy;
    final subscription = DashboardProfileCard(
      name: 'iPing',
      source: l.remote,
      updatedAt: host.updated,
      summary: DashboardConfigStats(
        groups: _snapshot?.groups,
        proxies: _snapshot?.proxies,
        rules: _snapshot?.rules,
      ),
      sync: DashboardIconButton(
        glyph: AppGlyphs.sync,
        tooltip: l.update,
        onPressed: host.busy ? null : host.synchronize,
      ),
      onDetails: () => host.openSubscription(context),
    );
    final intranet = DashboardIntranetCard(
      localIp: _snapshot?.localIp,
      allowLan: _snapshot?.settings['allow-lan'] == true,
      port: _snapshot?.settings['mixed-port'] as int? ?? 7890,
      onCopy: (address) async {
        await Clipboard.setData(ClipboardData(text: address));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.copySuccess)));
        }
      },
      onChanged: host.busy || _snapshot == null
          ? null
          : (value) => _saveSettings({'allow-lan': value}),
    );
    final services = _ServicesCard(host: host);
    final proxies = DashboardProxyGroupsFrame(
      count: host.connected ? _groups.length : 0,
      empty: Center(child: Text(l.noData, style: DashboardText.label(context))),
      onOpen: () => host.openProxies(context),
      itemBuilder: (context, index) {
        final item = _groups[index];
        final iconSize = DashboardDensityScope.of(context).isCompact
            ? 34.0
            : 40.0;
        return DashboardProxyGroupTile(
          name: item.name,
          icon: DashboardGroupIcon(
            name: item.name,
            src: item.icon,
            size: iconSize,
            radius: DashboardCorner.block - 10,
          ),
          selected: EmojiText(
            item.selected.isEmpty ? '—' : item.selected,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.rowTitle(context),
          ),
          onTap: () => host.openProxies(context),
        );
      },
    );
    final memory = ListenableBuilder(
      listenable: host.telemetryUpdates,
      builder: (context, _) => _MetricCard(
        glyph: AppGlyphs.memory,
        title: l.memoryInfo,
        value: '',
        content: DashboardMemorySummary(
          coreBytes: host.telemetry.memory,
          density: DashboardDensityScope.of(context),
        ),
      ),
    );
    final connections = ListenableBuilder(
      listenable: host.telemetryUpdates,
      builder: (context, _) => _MetricCard(
        glyph: AppGlyphs.connections,
        title: l.connections,
        value: host.connected ? host.telemetry.connections.toString() : '—',
        onTap: () => host.openConnections(context),
      ),
    );
    final groups = _MetricCard(
      glyph: AppGlyphs.proxies,
      title: l.proxies,
      value: host.connected ? '${_groups.length}' : '—',
      onTap: () => host.openProxies(context),
    );
    final feed = _FeedCard.connections(
      host: host,
      connectionItems: host.connected ? _connections : [],
      count: host.connected ? host.telemetry.connections : 0,
    );
    final network = _ControlCard(
      glyph: AppGlyphs.settings,
      label: l.network,
      onTap: () => host.openNetwork(context),
    );
    final sync = _ControlCard(
      glyph: AppGlyphs.refresh,
      label: l.sync,
      onTap: host.busy ? null : host.synchronize,
    );
    Widget fixed(double height, Widget child) => Builder(
      builder: (context) => SizedBox(
        height: height * DashboardDensityScope.scaleOf(context),
        child: child,
      ),
    );
    IpingDashboardCard card({
      required String id,
      required String label,
      required WidgetBuilder builder,
      required Glyph glyph,
      bool removable = true,
      String? description,
      List<IpingDashboardDesktopCard> desktop = const [],
    }) => IpingDashboardCard(
      id: id,
      label: (_) => label,
      description: description == null ? null : (_) => description,
      glyph: glyph,
      removable: removable,
      builder: builder,
      desktop: desktop,
    );
    return [
      card(
        id: 'currentOutbound',
        label: l.status,
        description: l.currentOutboundDesc,
        glyph: AppGlyphs.status,
        removable: false,
        builder: (_) => fixed(220, status),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.outbound,
            builder: (_) => status,
          ),
        ],
      ),
      card(
        id: 'networkSpeed',
        label: l.networkSpeed,
        glyph: AppGlyphs.speed,
        builder: (_) => _NetworkSpeedCard(host: host),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.upload,
            builder: (_) => upload,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.download,
            builder: (_) => download,
          ),
        ],
      ),
      card(
        id: 'outboundMode',
        label: l.outboundMode,
        glyph: AppGlyphs.split,
        builder: (_) => fixed(64, mode),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.mode,
            builder: (_) => mode,
          ),
        ],
      ),
      card(
        id: 'networkTakeover',
        label: l.networkTakeover,
        glyph: AppGlyphs.shuffle,
        builder: (_) => const IpingNetworkTakeoverCard(),
        desktop: [
          if (host.networkTakeover.supportsSystemProxy)
            IpingDashboardDesktopCard(
              area: IpingDashboardDesktopArea.control,
              builder: (_) => const IpingNetworkTakeoverTile(
                IpingTakeoverSwitch.systemProxy,
              ),
            ),
          if (host.networkTakeover.supportsTun)
            IpingDashboardDesktopCard(
              area: IpingDashboardDesktopArea.control,
              builder: (_) =>
                  const IpingNetworkTakeoverTile(IpingTakeoverSwitch.tun),
            ),
        ],
      ),
      card(
        id: 'profile',
        label: l.profile,
        glyph: AppGlyphs.profiles,
        builder: (_) => subscription,
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: (_) => subscription,
          ),
        ],
      ),
      card(
        id: 'intranet',
        label: l.intranetIP,
        glyph: AppGlyphs.devices,
        builder: (_) => intranet,
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: (_) => intranet,
          ),
        ],
      ),
      card(
        id: 'services',
        label: l.serviceStatus,
        glyph: AppGlyphs.verified,
        builder: (_) => services,
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: (_) => services,
          ),
        ],
      ),
      card(
        id: 'connections',
        label: l.connectionStats,
        description: l.connectionStatsDesc,
        glyph: AppGlyphs.connections,
        builder: (_) => fixed(152, connections),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.summary,
            builder: (_) => connections,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.table,
            builder: (_) => feed,
            span: 3,
          ),
        ],
      ),
      card(
        id: 'memory',
        label: l.memoryInfo,
        description: l.memoryInfoDesc,
        glyph: AppGlyphs.memory,
        builder: (_) => fixed(152, memory),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: (_) => memory,
          ),
        ],
      ),
      card(
        id: 'proxyGroups',
        label: l.proxyGroup,
        glyph: AppGlyphs.layers,
        builder: (_) => fixed(300, proxies),
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.summary,
            builder: (_) => groups,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.table,
            builder: (_) => proxies,
            span: 2,
          ),
        ],
      ),
      card(
        id: 'network',
        label: l.network,
        glyph: AppGlyphs.settings,
        builder: (_) => fixed(64, network),
        // Two takeover tiles already fill the wide control row.
        desktop: [
          if (!systemProxy)
            IpingDashboardDesktopCard(
              area: IpingDashboardDesktopArea.control,
              builder: (_) => network,
            ),
        ],
      ),
      card(
        id: 'sync',
        label: l.sync,
        glyph: AppGlyphs.refresh,
        builder: (_) => fixed(64, sync),
      ),
    ];
  }

  Future<void> _saveSettings(Map<String, Object?> changes) async {
    final host = IpingDashboardScope.read(context);
    try {
      await host.saveSettings(changes);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(host.errorText(context, error))));
      }
    }
  }

  Future<void> _restart(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final host = IpingDashboardScope.read(context);
    final result = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: l.restart,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.confirm),
          ),
        ],
        child: Text(l.restartCoreTip),
      ),
    );
    if (result == true) await host.setConnected(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _probes?.outbound.unwatch('');
    for (final target in _watchedServices) {
      _probes?.services.unwatch(target);
    }
    super.dispose();
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.host, required this.snapshot});
  final IpingDashboardHost host;
  final IpingDashboardSnapshot? snapshot;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.probes,
    builder: (context, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final l = AppLocalizations.of(context);
    final metrics = OutboundCardMetrics.of(DashboardDensityScope.of(context));
    final started = snapshot?.started;
    final probes = host.probes;
    final entry = probes.outbound.state.entryOf('');
    final ip = entry.value;
    final quality = ip == null ? null : probes.outbound.qualityOf(ip.ip);
    final qualityLoading =
        ip != null && probes.outbound.isQualityLoading(ip.ip);
    final routeFailed = probes.error != null;
    return DashboardOutboundCard(
      running: host.connected,
      ip: ip?.ip,
      countryCode: ip?.countryCode,
      hideIp: host.preferences.hideIp,
      loading:
          !routeFailed &&
          (ip == null ? entry.phase != ProbePhase.failed : qualityLoading),
      checking: !routeFailed && (entry.isLoading || qualityLoading),
      failed: routeFailed || entry.phase == ProbePhase.failed,
      typeLabel: quality?.type.label(context),
      qualityLabel: quality == null
          ? null
          : '${l.ipQualityShort} ${quality.level.label(context)}',
      qualityTone: switch (quality?.level) {
        IpQualityLevel.good => DashboardChipTone.ok,
        IpQualityLevel.risky => DashboardChipTone.warn,
        _ => DashboardChipTone.idle,
      },
      organization:
          quality?.organization ??
          (quality?.asn == null ? null : 'AS${quality!.asn}'),
      onRefresh: probes.outbound.refreshOutbound,
      onDetails: ip == null ? null : () => host.openIpQuality(context, ip.ip),
      runTime: _RunTime(started: started),
      toggle: Stack(
        alignment: Alignment.center,
        children: [
          ConnectionToggle(
            size: metrics.buttonSize,
            enabled: host.nodes > 0 && !host.busy,
            running: host.connected,
            suspended: host.suspended,
            tooltip: host.connected ? l.stop : l.start,
            disabledColor: DashboardColors.of(context).tone2,
            onPressed: () => host.setConnected(!host.connected),
          ),
          if (host.busy)
            SizedBox.square(
              dimension: metrics.buttonSize + 8,
              child: const CommonCircleLoading(size: 16),
            ),
        ],
      ),
      action: DashboardIconButton(
        glyph: AppGlyphs.settings,
        tooltip: l.network,
        onPressed: () => host.openNetwork(context),
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.host, required this.upload});
  final IpingDashboardHost host;
  final bool upload;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.telemetryUpdates,
    builder: (context, _) => DashboardTrafficSpeedCard(
      direction: upload ? TrafficDirection.upload : TrafficDirection.download,
      traffic: host.traffic,
      connected: host.connected,
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.host});
  final IpingDashboardHost host;

  @override
  Widget build(BuildContext context) => DashboardModeBar(
    mode: host.telemetry.mode,
    onChanged: host.busy ? null : host.setMode,
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.glyph,
    required this.title,
    required this.value,
    this.onTap,
    this.content,
  });
  final Glyph glyph;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final Widget? content;

  @override
  Widget build(BuildContext context) => DashboardCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardCardHeader(glyph: glyph, title: title, chevron: onTap != null),
        if (content case final content?) ...[
          const SizedBox(height: 6),
          Expanded(child: content),
        ] else ...[
          const Spacer(),
          Text(
            value,
            style: DashboardText.figure(context, AppTextStyle.title1),
          ),
        ],
      ],
    ),
  );
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.glyph, required this.label, this.onTap});
  final Glyph glyph;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DashboardCard(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    onTap: onTap,
    child: Row(
      spacing: 10,
      children: [
        GlyphIcon(glyph, size: 20),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
        ),
        const GlyphIcon(AppGlyphs.chevronForward, size: 14),
      ],
    ),
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard.connections({
    required this.host,
    required this.connectionItems,
    required this.count,
  });
  final IpingDashboardHost host;
  final List<TrackerInfo> connectionItems;
  final int count;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final height = dashboardTableTabHeight(density) * scale;
    void open() => host.openConnections(context);
    return DashboardRecordCard(
      header: DashboardCappedRow(
        start: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: DashboardConnectedGroup(
            children: [
              DashboardConnectedButton(
                selected: true,
                first: true,
                last: true,
                outer: height / 2,
                inner: 8,
                background: DashboardColors.of(context).tone,
                semanticLabel: l.liveConnections,
                onTap: open,
                builder: (foreground) => DashboardFeedSegment(
                  label: l.liveConnections,
                  count: DashboardFeedCount(count),
                  height: height,
                  foreground: foreground,
                ),
              ),
            ],
          ),
        ),
        end: DashboardIconButton(
          glyph: AppGlyphs.chevronForward,
          tooltip: l.liveConnections,
          onPressed: open,
        ),
      ),
      child: DashboardRecordTable<TrackerInfo>(
        tableId: 'dashboard.connections',
        items: connectionItems,
        rowHeight: dashboardTableRowHeight(density) * scale,
        columnsOf: (width) => dashboardConnectionColumns(context, width),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.host});
  final IpingDashboardHost host;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.probes,
    builder: (context, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final serviceState = host.probes.services.state;
    final shown = _serviceTargets(host.preferences).take(4).toList();
    return DashboardServiceCard(
      services: [
        for (final target in shown)
          DashboardServiceView(
            target,
            serviceState.valueOf(target),
            loading:
                host.probes.error == null && serviceState.isLoading(target),
            failed:
                host.probes.error != null ||
                serviceState.entryOf(target).phase == ProbePhase.failed,
          ),
      ],
      loading: host.probes.error == null && shown.any(serviceState.isLoading),
      onRefresh: () => host.probes.services.refresh(shown),
      onDetails: () => host.openServices(context),
    );
  }
}

class _NetworkSpeedCard extends StatelessWidget {
  const _NetworkSpeedCard({required this.host});
  final IpingDashboardHost host;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.telemetryUpdates,
    builder: (context, _) => DashboardNetworkSpeedCard(traffic: host.traffic),
  );
}

class _RunTime extends StatefulWidget {
  const _RunTime({required this.started});
  final DateTime? started;

  @override
  State<_RunTime> createState() => _RunTimeState();
}

class _RunTimeState extends State<_RunTime> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (IpingDashboardScope.read(context).visible &&
          PageActivityScope.isActiveOf(context)) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.started;
    return Text(
      started == null
          ? '—'
          : getTimeText(DateTime.now().difference(started).inMilliseconds),
      maxLines: 1,
      style: AppTextStyle.subheadline.of(context, emphasized: true).toTabular,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
