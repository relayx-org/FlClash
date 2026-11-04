import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/datetime.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
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
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../dashboard_host.dart';

List<ServiceTarget> _serviceTargets(IpingDashboardPreferences preferences) =>
    enabledServices(
      orderServiceTargets(preferences.serviceOrder),
      preferences.disabledServices,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = IpingDashboardScope.of(context);
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
    if (_loading || !host.hasSubscription || !host.visible || host.busy) {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final host = IpingDashboardScope.of(context);
    return CommonScaffold(
      backgroundColor: DashboardColors.of(context).page,
      title: l.dashboard,
      actions: [
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
            final status = _ConnectionCard(host: host, snapshot: _snapshot);
            final upload = _SpeedCard(host: host, upload: true);
            final download = _SpeedCard(host: host, upload: false);
            final mode = _ModeCard(host: host);
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
              empty: Center(
                child: Text(l.noData, style: DashboardText.label(context)),
              ),
              onOpen: () => host.openProxies(context),
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
                  density: density,
                ),
              ),
            );
            final summaries = [
              ListenableBuilder(
                listenable: host.telemetryUpdates,
                builder: (context, _) => _MetricCard(
                  glyph: AppGlyphs.connections,
                  title: l.connections,
                  value: host.connected
                      ? host.telemetry.connections.toString()
                      : '—',
                  onTap: () => host.openConnections(context),
                ),
              ),
              _MetricCard(
                glyph: AppGlyphs.proxies,
                title: l.proxies,
                value: host.connected ? '${_groups.length}' : '—',
                onTap: () => host.openProxies(context),
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
                            onTap: () => host.openNetwork(context),
                          ),
                        ),
                        (
                          1,
                          _ControlCard(
                            glyph: AppGlyphs.refresh,
                            label: l.sync,
                            onTap: host.busy ? null : host.synchronize,
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
                              host: host,
                              connectionItems: host.connected
                                  ? _connections
                                  : [],
                              count: host.connected
                                  ? host.telemetry.connections
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
                        _NetworkSpeedCard(host: host),
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
