import 'dart:math' as math;

import 'package:fl_clash/common/num.dart';
import 'package:fl_clash/iping/backend_telemetry.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:material_ui/material_ui.dart';

import 'speed_frame.dart';
import 'network_speed_frame.dart';

const _minSpeedScale = 8 * 1024.0;

enum TrafficDirection {
  upload,
  download;

  num of(Traffic traffic) => this == upload ? traffic.up : traffic.down;

  Glyph get glyph => this == upload ? AppGlyphs.arrowUp : AppGlyphs.arrowDown;

  Color colorOf(BuildContext context) => this == upload
      ? DashboardColors.of(context).series2
      : context.colorScheme.primary;

  Color glyphColorOf(BuildContext context) => this == upload
      ? context.colorScheme.onSurfaceVariant
      : context.colorScheme.primary;

  String labelOf(BuildContext context) => this == upload
      ? AppLocalizations.of(context).upload
      : AppLocalizations.of(context).download;
}

String _speedUnit(TrafficShow show) => '${show.unit}/s';

/// The zero line is the chart's bottom: a card lets the chart bleed past its
/// edge so idle traffic, or none sampled yet, leaves no line.
class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.direction, required this.traffics});

  final TrafficDirection direction;
  final IpingTrafficSnapshot traffics;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      values: [
        for (final traffic in traffics.samples)
          direction.of(traffic).toDouble(),
      ],
      revision: traffics.revision,
      capacity: traffics.capacity,
      minScale: _minSpeedScale,
      baselineRatio: 1,
      color: direction.colorOf(context),
    );
  }
}

/// The upload or the download on its own desktop card.
class DashboardTrafficSpeedCard extends StatelessWidget {
  const DashboardTrafficSpeedCard({
    super.key,
    required this.direction,
    required this.traffic,
    this.connected = true,
  });

  final IpingTrafficSnapshot traffic;
  final bool connected;

  final TrafficDirection direction;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final appLocalizations = AppLocalizations.of(context);
    final traffics = traffic;
    final total = direction.of(traffic.total);
    final current = direction.of(traffics.latest);
    final peak = traffics.samples.fold<num>(
      0,
      (peak, traffic) => math.max(peak, direction.of(traffic)),
    );
    final speed = current.traffic;
    return DashboardSpeedFrame(
      title: direction.labelOf(context),
      glyph: direction.glyph,
      glyphColor: direction.glyphColorOf(context),
      peakLabel: appLocalizations.trafficPeak('${dashboardTraffic(peak)}/s'),
      totalLabel: appLocalizations.trafficTotal(dashboardTraffic(total)),
      figure: DashboardTrafficFigure(
        value: connected ? speed.value : '—',
        unit: connected ? _speedUnit(speed) : '',
        style: compact ? AppTextStyle.largeTitle : AppTextStyle.display,
        unitStyle: AppTextStyle.subheadline,
      ),
      chart: _SpeedChart(direction: direction, traffics: traffics),
    );
  }
}

/// The phone's single card: both directions side by side.
class DashboardNetworkSpeedCard extends StatelessWidget {
  const DashboardNetworkSpeedCard({super.key, required this.traffic});

  final IpingTrafficSnapshot traffic;

  @override
  Widget build(BuildContext context) {
    final traffics = traffic;
    final total = traffic.total;
    final latest = traffics.latest;
    Widget tile(TrafficDirection direction) => NetworkSpeedTile(
      upload: direction == TrafficDirection.upload,
      speed: direction.of(latest),
      total: direction.of(total),
      values: [
        for (final traffic in traffics.samples)
          direction.of(traffic).toDouble(),
      ],
      revision: traffics.revision,
      capacity: traffics.capacity,
    );
    return NetworkSpeedFrame(
      upload: tile(TrafficDirection.upload),
      download: tile(TrafficDirection.download),
    );
  }
}
