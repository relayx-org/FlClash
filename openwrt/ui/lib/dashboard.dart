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
import 'package:fl_clash/views/dashboard/desktop_layout.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'controller.dart';
import 'pages.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null) return;
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && PageActivityScope.isActiveOf(context)) {
        unawaited(_load());
      }
    });
  }

  Future<void> _load() async {
    final router = RouterScope.of(context);
    if (_loading || !router.connected || router.busy) return;
    _loading = true;
    try {
      final (connections, proxies) = await (
        router.backend.readConnections(),
        router.backend.readProxies(),
      ).wait;
      if (!mounted) return;
      updateWhenRouteSettled(() {
        if (!mounted) return;
        setState(() {
          _connections = connections.items;
          _groups = proxies.groups;
        });
      });
    } catch (_) {
      if (mounted) {
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
    final router = RouterScope.of(context);
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
            final status = _ConnectionCard(router: router);
            final upload = _SpeedCard(router: router, upload: true);
            final download = _SpeedCard(router: router, upload: false);
            final mode = _ModeCard(router: router);
            final subscription = _SubscriptionCard(
              router: router,
              compact: false,
            );
            final memory = _MetricCard(
              glyph: AppGlyphs.memory,
              title: l.memoryInfo,
              value: '',
              content: DashboardMemorySummary(
                coreBytes: router.telemetry.memory,
                density: density,
              ),
            );
            final summaries = [
              _MetricCard(
                glyph: AppGlyphs.connections,
                title: l.connections,
                value: router.connected
                    ? router.telemetry.connections.toString()
                    : '—',
                onTap: () => showSheet<void>(
                  context: context,
                  builder: (_) => const RouterConnections(),
                ),
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
                  ? DashboardDesktopLayout(
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
                      middle: [
                        (1, _AccountCard(router: router)),
                        (1, subscription),
                        (1, _ServiceCard(router: router)),
                        (1, memory),
                      ],
                      summaries: summaries,
                      tablesMinHeight: (density.isCompact ? 248 : 276) * scale,
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
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _FeedCard.proxies(
                              groups: router.connected ? _groups : [],
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        dashboardMobileSideOf(constraints.maxWidth),
                        MediaQuery.paddingOf(context).top,
                        dashboardMobileSideOf(constraints.maxWidth),
                        BottomInsetScope.of(context) + 24,
                      ),
                      child: Column(
                        spacing: gap,
                        children: [
                          SizedBox(height: 220 * scale, child: status),
                          DashboardNetworkSpeedCard(traffic: router.traffic),
                          SizedBox(height: 64 * scale, child: mode),
                          SizedBox(height: 152 * scale, child: subscription),
                          SizedBox(height: 152 * scale, child: summaries.first),
                          SizedBox(height: 152 * scale, child: memory),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _restart(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final router = RouterScope.of(context);
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
    super.dispose();
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.router});
  final RouterController router;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final metrics = OutboundCardMetrics.of(DashboardDensityScope.of(context));
    return OutboundCardFrame(
      running: router.connected,
      label: l.status,
      header: DashboardCardHeader(
        glyph: AppGlyphs.status,
        title: l.status,
        leading: [
          DashboardChip(
            label: router.connected ? l.running : l.notRunning,
            tone: router.connected
                ? DashboardChipTone.ok
                : DashboardChipTone.idle,
            dot: router.connected,
          ),
        ],
      ),
      body: Row(
        spacing: 12,
        children: [
          SizedBox.square(
            dimension: metrics.badgeSize,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: DashboardColors.of(context).tone,
                shape: AppShape.md,
              ),
              child: const GlyphIcon(AppGlyphs.settings),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OpenWrt',
                  style: DashboardText.figure(context, metrics.ip),
                ),
                const SizedBox(height: 4),
                Text('iPing', style: DashboardText.label(context)),
              ],
            ),
          ),
        ],
      ),
      footer: Row(
        spacing: metrics.cellGap,
        children: [
          Expanded(
            child: _Cell(label: l.ipingAccount, value: router.email),
          ),
          _Cell(label: l.proxies, value: '${router.nodes}'),
        ],
      ),
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
        glyph: AppGlyphs.account,
        tooltip: l.ipingAccount,
        onPressed: () => router.client.open('${router.site}/home'),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: DashboardText.label(context)),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.subheadline.of(context, emphasized: true),
      ),
    ],
  );
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.router, required this.upload});
  final RouterController router;
  final bool upload;
  @override
  Widget build(BuildContext context) => DashboardTrafficSpeedCard(
    direction: upload ? TrafficDirection.upload : TrafficDirection.download,
    traffic: router.traffic,
    connected: router.connected,
  );
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.router, required this.compact});
  final RouterController router;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DashboardCard(
      onTap: () => showSheet<void>(
        context: context,
        builder: (_) => const RouterSubscription(),
      ),
      child: compact
          ? DashboardCardHeader(
              glyph: AppGlyphs.profiles,
              title: l.subscriptionInfo,
              trailing: [
                Text(
                  l.ipingNodeCount(router.nodes),
                  style: DashboardText.label(context),
                ),
              ],
              chevron: true,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardCardHeader(
                  glyph: AppGlyphs.profiles,
                  title: l.subscriptionInfo,
                  chevron: true,
                ),
                const SizedBox(height: 16),
                Text('iPing', style: AppTextStyle.headline.of(context)),
                const Spacer(),
                Text(
                  l.ipingNodeCount(router.nodes),
                  style: DashboardText.label(context),
                ),
              ],
            ),
    );
  }
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.router});
  final RouterController router;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DashboardCard(
      onTap: () => router.client.open('${router.site}/home'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.account,
            title: l.ipingAccount,
            chevron: true,
          ),
          const Spacer(),
          Text(
            'iPing',
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          const SizedBox(height: 8),
          Text(
            router.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.router});
  final RouterController router;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(glyph: AppGlyphs.status, title: l.serviceStatus),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'iPing',
                style: AppTextStyle.subheadline.of(context, emphasized: true),
              ),
              DashboardChip(
                label: router.connected ? l.running : l.notRunning,
                tone: router.connected
                    ? DashboardChipTone.ok
                    : DashboardChipTone.idle,
                dot: router.connected,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.ipingNodeCount(router.nodes),
            style: DashboardText.label(context),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard.connections({required this.connectionItems})
    : connections = true,
      groups = const [];
  const _FeedCard.proxies({required this.groups})
    : connections = false,
      connectionItems = const [];
  final bool connections;
  final List<TrackerInfo> connectionItems;
  final List<IpingProxyGroup> groups;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final padding = dashboardCardPadding(DashboardDensityScope.of(context));
    return DashboardCard(
      padding: EdgeInsets.zero,
      onTap: () => showSheet<void>(
        context: context,
        builder: (_) =>
            connections ? const RouterConnections() : const RouterProxies(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: DashboardCardHeader(
              glyph: connections ? AppGlyphs.connections : AppGlyphs.proxies,
              title: connections ? l.connections : l.proxies,
              chevron: true,
            ),
          ),
          Expanded(
            child: connections
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DashboardRecordTable<TrackerInfo>(
                      tableId: 'dashboard.connections',
                      items: connectionItems,
                      rowHeight:
                          (DashboardDensityScope.of(context).isCompact
                              ? 32
                              : 34) *
                          DashboardDensityScope.scaleOf(context),
                      columnsOf: (width) =>
                          dashboardConnectionColumns(context, width),
                    ),
                  )
                : groups.isEmpty
                ? Center(
                    child: Text(l.noData, style: DashboardText.label(context)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final item = groups[index];
                      final name = item.name;
                      final detail = item.selected.isEmpty
                          ? '—'
                          : item.selected;
                      final trailing = item.type;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          spacing: 12,
                          children: [
                            GlyphIcon(
                              connections
                                  ? AppGlyphs.connections
                                  : AppGlyphs.proxies,
                              size: 18,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  EmojiText(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyle.subheadline.of(context),
                                  ),
                                  const SizedBox(height: 3),
                                  EmojiText(
                                    detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DashboardText.label(context),
                                  ),
                                ],
                              ),
                            ),
                            Text(trailing, style: DashboardText.label(context)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
