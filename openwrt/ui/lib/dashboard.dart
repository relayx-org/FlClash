import 'package:fl_clash/views/dashboard/widgets/record_frame.dart';
import 'package:fl_clash/common/datetime.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_content.dart';
import 'package:fl_clash/views/dashboard/widgets/intranet_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/service_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/proxy_groups_frame.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/views/dashboard/widgets/record_table.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_summary.dart';
import 'package:fl_clash/views/dashboard/widgets/mode_control.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_frame.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/panel_layout.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'controller.dart';
import 'pages.dart';
import 'probes.dart';
import 'settings.dart';

class RouterDashboard extends StatefulWidget {
  const RouterDashboard({super.key});

  @override
  State<RouterDashboard> createState() => _RouterDashboardState();
}

class _RouterDashboardState extends State<RouterDashboard>
    with RouteMotionHoldMixin {
  Timer? _timer;
  bool _loading = false;
  List<TrackerInfo> _connections = [];
  List<IpingProxyGroup> _groups = [];
  IpingDashboardSnapshot? _snapshot;
  RouterController? _router;
  Set<ServiceTarget> _watchedServices = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    if (_router == null) {
      _router = router;
      router.probes.outbound.watch('');
    }
    final targets = routerServiceTargets(
      RouterAppState.of(context).preferences,
    ).take(4).toSet();
    for (final target in targets.difference(_watchedServices)) {
      router.probes.services.watch(target);
    }
    for (final target in _watchedServices.difference(targets)) {
      router.probes.services.unwatch(target);
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
    final router = _router!;
    if (_loading || !router.signedIn || !router.visible || router.busy) return;
    _loading = true;
    final tables = !context.isMobileView;
    try {
      final (snapshot, connections, proxies) = await (
        router.readDashboard(),
        tables && router.connected
            ? router.backend.readConnections()
            : Future.value(const IpingConnectionPage()),
        tables && router.connected
            ? router.backend.readProxies()
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    return CommonScaffold(
      backgroundColor: DashboardColors.of(context).page,
      title: l.dashboard,
      actions: [
        FilledButton.icon(
          style: ElasticPress.buttonStyle,
          onPressed: router.busy ? null : () => _restart(context),
          icon: router.busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : GlyphIcon(
                  router.connected ? AppGlyphs.check : AppGlyphs.close,
                  fill: 1,
                ),
          label: Text(router.connected ? l.running : l.notRunning),
        ),
      ],
      body: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.max(
              1.0,
              MediaQuery.textScalerOf(context).scale(1),
            );
            final density = DashboardDensity.of(constraints.biggest / scale);
            final gap = density.isDesktop
                ? (MediaQuery.sizeOf(context).width <= 840 ? 12.0 : 16.0)
                : 8.0;
            final status = _ConnectionCard(router: router, snapshot: _snapshot);
            final upload = _SpeedCard(router: router, upload: true);
            final download = _SpeedCard(router: router, upload: false);
            final mode = _ModeCard(router: router);
            final subscription = DashboardProfileCard(
              name: 'iPing',
              source: l.remote,
              updatedAt: router.status.updated,
              summary: DashboardConfigStats(
                groups: _snapshot?.groups,
                proxies: _snapshot?.proxies,
                rules: _snapshot?.rules,
              ),
              sync: DashboardIconButton(
                glyph: AppGlyphs.sync,
                tooltip: l.update,
                onPressed: router.busy ? null : router.synchronize,
              ),
              onDetails: () => showSheet<void>(
                context: context,
                builder: (_) => const RouterSubscription(),
              ),
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
              onChanged: router.busy || _snapshot == null
                  ? null
                  : (value) => _saveSettings({'allow-lan': value}),
            );
            const services = _ServicesCard();
            final proxies = DashboardProxyGroupsFrame(
              count: router.connected ? _groups.length : 0,
              empty: Center(
                child: Text(l.noData, style: DashboardText.label(context)),
              ),
              onOpen: () => showSheet<void>(
                context: context,
                builder: (_) => const RouterProxies(),
              ),
              itemBuilder: (context, index) {
                final item = _groups[index];
                final iconSize = density.isCompact ? 34.0 : 40.0;
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
                  onTap: () => showSheet<void>(
                    context: context,
                    builder: (_) => const RouterProxies(),
                  ),
                );
              },
            );
            final memory = Builder(
              builder: (context) {
                final router = RouterScope.of(
                  context,
                  aspect: RouterAspect.telemetry,
                );
                return _MetricCard(
                  glyph: AppGlyphs.memory,
                  title: l.memoryInfo,
                  value: '',
                  content: DashboardMemorySummary(
                    coreBytes: router.telemetry.memory,
                    density: density,
                  ),
                );
              },
            );
            final summaries = [
              Builder(
                builder: (context) {
                  final router = RouterScope.of(
                    context,
                    aspect: RouterAspect.telemetry,
                  );
                  return _MetricCard(
                    glyph: AppGlyphs.connections,
                    title: l.connections,
                    value: router.connected
                        ? router.telemetry.connections.toString()
                        : '—',
                    onTap: () => showSheet<void>(
                      context: context,
                      builder: (_) => const RouterConnections(),
                    ),
                  );
                },
              ),
              _MetricCard(
                glyph: AppGlyphs.proxies,
                title: l.proxies,
                value: router.connected ? '${_groups.length}' : '—',
                onTap: () => showSheet<void>(
                  context: context,
                  builder: (_) => const RouterProxies(),
                ),
              ),
            ];
            return DashboardDensityScope(
              density: density,
              scale: scale,
              child: density.isDesktop
                  ? DashboardPanelLayout(
                      columns: dashboardColumnsOf(constraints.maxWidth / scale),
                      gap: gap,
                      outbound: status,
                      upload: upload,
                      download: download,
                      mode: mode,
                      controls: [
                        (
                          1,
                          _ControlCard(
                            glyph: AppGlyphs.settings,
                            label: l.network,
                            onTap: () => showSheet<void>(
                              context: context,
                              builder: (_) => const RouterCoreSettings(
                                kind: RouterSettingsKind.network,
                              ),
                            ),
                          ),
                        ),
                        (
                          1,
                          _ControlCard(
                            glyph: AppGlyphs.refresh,
                            label: l.sync,
                            onTap: router.busy
                                ? null
                                : () => router.synchronize(),
                          ),
                        ),
                      ],
                      intranet: intranet,
                      profile: subscription,
                      services: services,
                      memory: memory,
                      summaries: summaries,
                      tablesMinHeight: connectionsTableMinHeight(
                        density,
                        scale,
                      ),
                      tables: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: gap,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _FeedCard.connections(
                              connectionItems: router.connected
                                  ? _connections
                                  : [],
                              count: router.connected
                                  ? router.telemetry.connections
                                  : 0,
                            ),
                          ),
                          Expanded(flex: 2, child: proxies),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        dashboardMobileSideOf(constraints.maxWidth),
                        MediaQuery.paddingOf(context).top,
                        dashboardMobileSideOf(constraints.maxWidth),
                        BottomInsetScope.of(context) + 24,
                      ),
                      itemCount: 8,
                      separatorBuilder: (_, _) => SizedBox(height: gap),
                      itemBuilder: (context, index) => [
                        SizedBox(height: 220 * scale, child: status),
                        const _NetworkSpeedCard(),
                        SizedBox(height: 64 * scale, child: mode),
                        subscription,
                        intranet,
                        services,
                        SizedBox(height: 152 * scale, child: summaries.first),
                        SizedBox(height: 152 * scale, child: memory),
                      ][index],
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveSettings(Map<String, Object?> changes) async {
    final router = RouterScope.read(context);
    try {
      await router.saveSettings(changes);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(routerError(context, error.toString()))),
        );
      }
    }
  }

  Future<void> _restart(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final router = RouterScope.read(context);
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
    if (result == true) await router.setConnected(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _router?.probes.outbound.unwatch('');
    for (final target in _watchedServices) {
      _router?.probes.services.unwatch(target);
    }
    super.dispose();
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.router, required this.snapshot});
  final RouterController router;
  final IpingDashboardSnapshot? snapshot;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final metrics = OutboundCardMetrics.of(DashboardDensityScope.of(context));
    final started = snapshot?.started;
    RouterScope.of(context, aspect: RouterAspect.probes);
    final entry = router.probes.outbound.state.entryOf('');
    final ip = entry.value;
    final quality = ip == null ? null : router.probes.qualityOf(ip.ip);
    final qualityLoading = ip != null && router.probes.isQualityLoading(ip.ip);
    final routeFailed = router.probes.error != null;
    return DashboardOutboundCard(
      running: router.connected,
      ip: ip?.ip,
      countryCode: ip?.countryCode,
      hideIp: RouterAppState.of(context).preferences.hideIp,
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
      onRefresh: router.probes.refreshOutbound,
      onDetails: ip == null
          ? null
          : () => showSheet<void>(
              context: context,
              builder: (_) => RouterIpQuality(ip: ip.ip),
            ),
      runTime: _RunTime(started: started),
      toggle: Stack(
        alignment: Alignment.center,
        children: [
          ConnectionToggle(
            size: metrics.buttonSize,
            enabled: router.nodes > 0 && !router.busy,
            running: router.connected,
            suspended: false,
            tooltip: router.connected ? l.stop : l.start,
            disabledColor: DashboardColors.of(context).tone2,
            onPressed: () => router.setConnected(!router.connected),
          ),
          if (router.busy)
            SizedBox.square(
              dimension: metrics.buttonSize + 8,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      action: DashboardIconButton(
        glyph: AppGlyphs.settings,
        tooltip: l.network,
        onPressed: () => showSheet<void>(
          context: context,
          builder: (_) =>
              const RouterCoreSettings(kind: RouterSettingsKind.network),
        ),
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.router, required this.upload});
  final RouterController router;
  final bool upload;
  @override
  Widget build(BuildContext context) {
    RouterScope.of(context, aspect: RouterAspect.telemetry);
    return DashboardTrafficSpeedCard(
      direction: upload ? TrafficDirection.upload : TrafficDirection.download,
      traffic: router.traffic,
      connected: router.connected,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.router});
  final RouterController router;

  @override
  Widget build(BuildContext context) => DashboardModeBar(
    mode: router.telemetry.mode,
    onChanged: router.busy ? null : router.setMode,
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
    required this.connectionItems,
    required this.count,
  });
  final List<TrackerInfo> connectionItems;
  final int count;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final height = dashboardTableTabHeight(density) * scale;
    void open() => showSheet<void>(
      context: context,
      builder: (_) => const RouterConnections(),
    );
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
  const _ServicesCard();

  @override
  Widget build(BuildContext context) {
    final router = RouterScope.of(context, aspect: RouterAspect.probes);
    final serviceState = router.probes.services.state;
    final shown = routerServiceTargets(
      RouterAppState.of(context).preferences,
    ).take(4).toList();
    return DashboardServiceCard(
      services: [
        for (final target in shown)
          DashboardServiceView(
            target,
            serviceState.valueOf(target),
            loading:
                router.probes.error == null && serviceState.isLoading(target),
            failed:
                router.probes.error != null ||
                serviceState.entryOf(target).phase == ProbePhase.failed,
          ),
      ],
      loading: router.probes.error == null && shown.any(serviceState.isLoading),
      onRefresh: () => router.probes.services.refresh(shown),
      onDetails: () => showSheet<void>(
        context: context,
        builder: (_) => const RouterServiceStatus(),
      ),
    );
  }
}

class _NetworkSpeedCard extends StatelessWidget {
  const _NetworkSpeedCard();

  @override
  Widget build(BuildContext context) => DashboardNetworkSpeedCard(
    traffic: RouterScope.of(context, aspect: RouterAspect.telemetry).traffic,
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
      if (RouterScope.read(context).visible &&
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
