import 'dart:math';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/common/service_probe_data.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

String dashboardServiceStatusLabel(
  BuildContext context,
  ServiceProbeStatus status,
) {
  final localizations = AppLocalizations.of(context);
  return switch (status) {
    ServiceProbeStatus.available => localizations.serviceAvailable,
    ServiceProbeStatus.restricted => localizations.serviceRestricted,
    ServiceProbeStatus.unavailable => localizations.serviceUnavailable,
    ServiceProbeStatus.disallowedIsp => localizations.serviceDisallowedIsp,
    ServiceProbeStatus.blocked => localizations.serviceBlocked,
    ServiceProbeStatus.unsupportedRegion =>
      localizations.serviceUnsupportedRegion,
    ServiceProbeStatus.originalsOnly => localizations.serviceOriginalsOnly,
    ServiceProbeStatus.comingSoon => localizations.serviceComingSoon,
    ServiceProbeStatus.timeout => localizations.timeout,
    ServiceProbeStatus.failed => localizations.serviceFailed,
  };
}

typedef DashboardServiceColors = ({
  Color color,
  Color container,
  Color onContainer,
});

DashboardServiceColors dashboardServiceStatusColors(
  BuildContext context,
  ServiceProbeStatus status,
) {
  final colorScheme = context.colorScheme;
  return switch (status) {
    ServiceProbeStatus.available => (
      color: colorScheme.success,
      container: colorScheme.successContainer,
      onContainer: colorScheme.onSuccessContainer,
    ),
    ServiceProbeStatus.restricted ||
    ServiceProbeStatus.disallowedIsp ||
    ServiceProbeStatus.blocked ||
    ServiceProbeStatus.unsupportedRegion ||
    ServiceProbeStatus.originalsOnly ||
    ServiceProbeStatus.comingSoon => (
      color: colorScheme.warning,
      container: colorScheme.warningContainer,
      onContainer: colorScheme.onWarningContainer,
    ),
    ServiceProbeStatus.unavailable ||
    ServiceProbeStatus.timeout ||
    ServiceProbeStatus.failed => (
      color: colorScheme.error,
      container: colorScheme.errorContainer,
      onContainer: colorScheme.onErrorContainer,
    ),
  };
}

Color dashboardServiceStatusColor(
  BuildContext context,
  ServiceProbeStatus status,
) => dashboardServiceStatusColors(context, status).color;

DashboardServiceColors dashboardServiceIdleColors(BuildContext context) => (
  color: context.colorScheme.onSurfaceVariant,
  container: context.raisedSurfaceLevel.colorOf(context.colorScheme),
  onContainer: context.colorScheme.onSurfaceVariant,
);

(String, DashboardServiceColors) dashboardServiceStatusOf(
  BuildContext context,
  ServiceCheck? check, {
  bool loading = false,
  bool failed = false,
}) {
  final localizations = AppLocalizations.of(context);
  if (loading) {
    return (localizations.loading, dashboardServiceIdleColors(context));
  }
  if (check != null) {
    return (
      dashboardServiceStatusLabel(context, check.status),
      dashboardServiceStatusColors(context, check.status),
    );
  }
  if (failed) {
    return (
      dashboardServiceStatusLabel(context, ServiceProbeStatus.failed),
      dashboardServiceStatusColors(context, ServiceProbeStatus.failed),
    );
  }
  return (localizations.servicePending, dashboardServiceIdleColors(context));
}

class DashboardServiceView {
  const DashboardServiceView(
    this.target,
    this.check, {
    bool loading = false,
    this.failed = false,
  }) : _loading = loading;

  final ServiceTarget target;
  final bool _loading;
  final bool failed;
  final ServiceCheck? check;

  bool get loading => _loading && check == null;

  bool get abnormal => switch (check) {
    final check? => check.status != ServiceProbeStatus.available,
    null => failed,
  };

  (String, Color) statusOf(BuildContext context) => switch (check) {
    ServiceCheck(status: ServiceProbeStatus.available, :final delay) => (
      delay != null
          ? '$delay ms'
          : dashboardServiceStatusLabel(context, ServiceProbeStatus.available),
      context.colorScheme.onSurfaceVariant,
    ),
    final ServiceCheck check => (
      dashboardServiceStatusLabel(context, check.status),
      dashboardServiceStatusColor(context, check.status),
    ),
    null => switch (dashboardServiceStatusOf(
      context,
      null,
      loading: loading,
      failed: failed,
    )) {
      (final label, final colors) => (label, colors.color),
    },
  };

  Color? dotOf(BuildContext context) => switch (check) {
    final check? => dashboardServiceStatusColor(context, check.status),
    null when failed => context.colorScheme.error,
    null => null,
  };
}

class DashboardServiceCard extends StatelessWidget {
  const DashboardServiceCard({
    super.key,
    required this.services,
    this.loading = false,
    this.onRefresh,
    this.onDetails,
  });
  final List<DashboardServiceView> services;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final mobile = !density.isDesktop;
    final appLocalizations = AppLocalizations.of(context);
    final problems = services.where((service) => service.abnormal).length;
    final verdict = problems > 0
        ? DashboardChip(
            label: appLocalizations.serviceAbnormalCount(problems),
            tone: DashboardChipTone.warn,
          )
        : services.every((service) => service.check != null)
        ? DashboardChip(
            label: appLocalizations.serviceAllAvailable,
            tone: DashboardChipTone.ok,
          )
        : null;
    final scale = DashboardDensityScope.scaleOf(context);
    final grid = _ServiceGrid(
      services: services,
      fill: !mobile,
      cellHeight:
          (mobile
              ? 50
              : density.isCompact
              ? 40
              : 46) *
          scale,
      gap: density.isCompact ? 6 : 8,
    );
    return DashboardCard(
      semanticLabel: appLocalizations.serviceStatus,
      onTap: mobile ? onDetails : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.verified,
            title: appLocalizations.serviceStatus,
            chevron: mobile,
            trailing: [
              ?verdict,
              if (!mobile)
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CheckAllButton(loading: loading, onPressed: onRefresh),
                      DashboardIconButton(
                        glyph: AppGlyphs.chevronForward,
                        tooltip: appLocalizations.serviceStatus,
                        onPressed: onDetails,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (mobile) const SizedBox(height: 12) else const Spacer(),
          grid,
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    required this.services,
    required this.fill,
    required this.cellHeight,
    required this.gap,
  });

  static const _columns = 2;

  final List<DashboardServiceView> services;

  /// Keeps the two rows four services take on a card of fixed height, the
  /// cells of a single row growing into tiles.
  final bool fill;
  final double cellHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (fill && services.length <= _columns) {
      return SizedBox(
        height: cellHeight * 2 + gap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (final service in services)
              Expanded(
                child: _ServiceCell(
                  service: service,
                  height: cellHeight,
                  tile: true,
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        for (var start = 0; start < services.length; start += _columns)
          Row(
            spacing: gap,
            children: [
              for (final service in services.skip(start).take(_columns))
                Expanded(
                  child: _ServiceCell(service: service, height: cellHeight),
                ),
            ],
          ),
      ],
    );
  }
}

class _ServiceCell extends StatelessWidget {
  const _ServiceCell({
    required this.service,
    required this.height,
    this.tile = false,
  });

  static const _inset = 7.0;

  // Lines the text up with the 12 a cell keeps clear at its end.
  static const _tileText = EdgeInsetsDirectional.fromSTEB(5, 0, 5, 3);

  final DashboardServiceView service;
  final double height;

  final bool tile;

  @override
  Widget build(BuildContext context) {
    final (label, color) = service.statusOf(context);
    final status = AppTextStyle.caption1
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: color);
    final badge = DashboardServiceBadge(
      target: service.target,
      size: height - _inset * 2,
      radius: DashboardCorner.tab - _inset,
      color: DashboardColors.of(context).card,
      ink: context.colorScheme.onSurfaceVariant,
      dot: service.dotOf(context),
    );
    final text = ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.target.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.footnote.of(context, emphasized: true),
          ),
          if (service.loading)
            SkeletonText(width: 44, style: status)
          else
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: status,
            ),
        ],
      ),
    );
    return Semantics(
      label: service.target.label,
      value: label,
      liveRegion: true,
      child: tile
          ? DashboardBlock(
              radius: DashboardCorner.tab,
              padding: const EdgeInsets.all(_inset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  Padding(padding: _tileText, child: text),
                ],
              ),
            )
          : SizedBox(
              height: height,
              child: DashboardBlock(
                radius: DashboardCorner.tab,
                padding: const EdgeInsetsDirectional.fromSTEB(_inset, 0, 12, 0),
                child: Row(
                  spacing: 8,
                  children: [
                    badge,
                    Expanded(child: text),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CheckAllButton extends StatelessWidget {
  const _CheckAllButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox.square(
        dimension: 32,
        child: Center(child: CommonCircleLoading(size: 18)),
      );
    }
    return DashboardIconButton(
      glyph: AppGlyphs.bolt,
      tooltip: AppLocalizations.of(context).serviceCheckAll,
      onPressed: onPressed,
    );
  }
}

class DashboardServiceBadge extends StatelessWidget {
  const DashboardServiceBadge({
    super.key,
    required this.target,
    required this.size,
    this.radius,
    this.dot,
    this.enabled = true,
    this.color,
    this.ink,
  });

  static const _glyphShare = 0.56;

  final ServiceTarget target;
  final double size;
  final double? radius;
  final Color? dot;
  final bool enabled;
  final Color? color;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _BadgePainter(
        color: color ?? context.raisedSurfaceLevel.colorOf(colorScheme),
        radius: radius ?? AppCorner.fit(size),
        dot: dot,
        dotRadius: max(size / 10, 4),
        ring: max(size / 16, 2),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: SvgPicture.asset(
            'assets/images/services/${target.icon}.svg',
            width: size * _glyphShare,
            height: size * _glyphShare,
            excludeFromSemantics: true,
            theme: SvgTheme(
              currentColor:
                  ink ??
                  (enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurfaceVariant.opacity38),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({
    required this.color,
    required this.radius,
    required this.dot,
    required this.dotRadius,
    required this.ring,
  });

  final Color color;
  final double radius;
  final Color? dot;
  final double dotRadius;
  final double ring;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final tile = RSuperellipse.fromRectAndRadius(
      bounds,
      Radius.circular(radius),
    );
    final dot = this.dot;
    if (dot == null) {
      canvas.drawRSuperellipse(tile, Paint()..color = color);
      return;
    }
    final center = size.bottomRight(Offset(-dotRadius, -dotRadius));
    final gap = Path()
      ..addOval(Rect.fromCircle(center: center, radius: dotRadius + ring));
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRSuperellipse(tile),
          gap,
        ),
        Paint()..color = color,
      )
      ..drawCircle(center, dotRadius, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dot != dot ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.ring != ring;
}
