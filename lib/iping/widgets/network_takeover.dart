import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:material_ui/material_ui.dart';

typedef _RowMetrics = ({
  EdgeInsets padding,
  double titleStart,
  double radius,
  double icon,
  bool subtitle,
});

const _RowMetrics _cardRowMetrics = (
  padding: EdgeInsets.fromLTRB(10, 10, 12, 10),
  titleStart: 14,
  radius: 20,
  icon: 38,
  subtitle: true,
);

_RowMetrics _tileMetricsOf(DashboardDensity density) => density.isCompact
    ? (
        padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
        titleStart: dashboardCardPadding(density).left,
        radius: dashboardCardRadius(density),
        icon: 36,
        subtitle: false,
      )
    : (
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
        titleStart: dashboardCardPadding(density).left,
        radius: dashboardCardRadius(density),
        icon: 40,
        subtitle: true,
      );

enum IpingTakeoverSwitch { systemProxy, tun }

String _titleOf(BuildContext context, IpingTakeoverSwitch kind) {
  final appLocalizations = AppLocalizations.of(context);
  return switch (kind) {
    IpingTakeoverSwitch.systemProxy => appLocalizations.systemProxy,
    IpingTakeoverSwitch.tun => appLocalizations.tun,
  };
}

bool _supports(IpingNetworkTakeover takeover, IpingTakeoverSwitch kind) =>
    switch (kind) {
      IpingTakeoverSwitch.systemProxy => takeover.supportsSystemProxy,
      IpingTakeoverSwitch.tun => takeover.supportsTun,
    };

class _TakeoverRow extends StatefulWidget {
  const _TakeoverRow({
    required this.kind,
    required this.metrics,
    required this.showIcon,
    this.color,
  });

  final IpingTakeoverSwitch kind;
  final _RowMetrics metrics;
  final bool showIcon;
  final Color? color;

  @override
  State<_TakeoverRow> createState() => _TakeoverRowState();
}

class _TakeoverRowState extends State<_TakeoverRow> {
  bool _saving = false;

  Future<void> _change(bool value) async {
    if (_saving) return;
    final host = IpingDashboardScope.read(context);
    setState(() => _saving = true);
    try {
      final takeover = host.networkTakeover;
      switch (widget.kind) {
        case IpingTakeoverSwitch.systemProxy:
          await takeover.setSystemProxy(value);
        case IpingTakeoverSwitch.tun:
          await takeover.setTun(value);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(host.errorText(context, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final host = IpingDashboardScope.of(context);
    final takeover = host.networkTakeover;
    final systemProxy = widget.kind == IpingTakeoverSwitch.systemProxy;
    final value = systemProxy ? takeover.systemProxy : takeover.tun;
    final busy = _saving || host.busy;
    final metrics = widget.metrics;
    return DashboardSwitchRow(
      glyph: systemProxy ? AppGlyphs.shuffle : AppGlyphs.vpn,
      title: _titleOf(context, widget.kind),
      subtitle: metrics.subtitle
          ? value
                ? appLocalizations.enabled
                : appLocalizations.disabled
          : null,
      value: value,
      iconSize: metrics.icon,
      padding: widget.showIcon
          ? metrics.padding
          : metrics.padding.copyWith(left: metrics.titleStart),
      radius: metrics.radius,
      color: widget.color,
      showIcon: widget.showIcon,
      onTap: busy ? null : () => _change(!value),
      onChanged: busy ? null : _change,
    );
  }
}

/// Both switches in one card, for the card list of a narrow window.
class IpingNetworkTakeoverCard extends StatelessWidget {
  const IpingNetworkTakeoverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final takeover = IpingDashboardScope.of(context).networkTakeover;
    final switches = [
      for (final kind in IpingTakeoverSwitch.values)
        if (_supports(takeover, kind)) kind,
    ];
    if (switches.isEmpty) return const SizedBox.shrink();
    const metrics = _cardRowMetrics;
    return DashboardCard(
      semanticLabel: appLocalizations.networkTakeover,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.shuffle,
            title: appLocalizations.networkTakeover,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final showIcon = DashboardSwitchRow.iconFits(
                context,
                width: constraints.maxWidth,
                iconSize: metrics.icon,
                padding: metrics.padding,
                titles: [for (final kind in switches) _titleOf(context, kind)],
              );
              return Column(
                spacing: 8,
                children: [
                  for (final kind in switches)
                    _TakeoverRow(
                      kind: kind,
                      metrics: metrics,
                      showIcon: showIcon,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One switch as a card of its own, in the desktop's control row.
class IpingNetworkTakeoverTile extends StatelessWidget {
  const IpingNetworkTakeoverTile(this.kind, {super.key});

  final IpingTakeoverSwitch kind;

  @override
  Widget build(BuildContext context) {
    final takeover = IpingDashboardScope.of(context).networkTakeover;
    if (!_supports(takeover, kind)) return const SizedBox.shrink();
    final metrics = _tileMetricsOf(DashboardDensityScope.of(context));
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) => _TakeoverRow(
          kind: kind,
          metrics: metrics,
          color: Colors.transparent,
          showIcon: DashboardSwitchRow.iconFits(
            context,
            width: constraints.maxWidth,
            iconSize: metrics.icon,
            padding: metrics.padding,
            titles: [
              for (final kind in IpingTakeoverSwitch.values)
                if (_supports(takeover, kind)) _titleOf(context, kind),
            ],
          ),
        ),
      ),
    );
  }
}
