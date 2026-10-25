import 'dart:math' as math;

import 'package:fl_clash/ui/ui.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

const _decorationGrowth = 0.12;
const _decorationTurn = 2 * math.pi / 12;
const _morphDuration = Duration(milliseconds: 450);

class OutboundCardFrame extends StatelessWidget {
  const OutboundCardFrame({
    super.key,
    required this.running,
    required this.label,
    required this.header,
    required this.body,
    required this.footer,
    required this.toggle,
    this.action,
  });

  final bool running;
  final String label;
  final Widget header;
  final Widget body;
  final Widget footer;
  final Widget toggle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final metrics = OutboundCardMetrics.of(density);
    final colors = DashboardColors.of(context);
    final colorScheme = context.colorScheme;
    return DashboardCard(
      padding: EdgeInsets.zero,
      semanticLabel: label,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShape.all(dashboardCardRadius(density)),
                textDirection: Directionality.of(context),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    end: metrics.decorationEnd,
                    top: metrics.decorationTop,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: running ? 1 : 0),
                      duration: context.motionDuration(_morphDuration),
                      curve: Curves.easeOutBack,
                      builder: (_, progress, _) => Transform.rotate(
                        angle: _decorationTurn * progress,
                        child: Transform.scale(
                          scale: 1 + _decorationGrowth * progress,
                          child: ShapeBadge(
                            shape: MaterialShapes.cookie12Sided,
                            color: Color.lerp(
                              colors.tone,
                              Color.alphaBlend(
                                colorScheme.primary.withValues(alpha: 0.1),
                                colors.card,
                              ),
                              progress.clamp(0, 1),
                            )!,
                            size: metrics.decorationSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: metrics.padding,
            child: Row(
              spacing: metrics.gap,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      SizedBox(height: metrics.ipTop),
                      body,
                      if (density.isDesktop)
                        const Spacer()
                      else
                        const SizedBox(height: 16),
                      footer,
                    ],
                  ),
                ),
                SizedBox(
                  width: metrics.buttonSlot,
                  child: Center(child: toggle),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: metrics.padding.resolve(Directionality.of(context)).top,
            end:
                metrics.padding.resolve(Directionality.of(context)).horizontal /
                2,
            child: action ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class OutboundCardMetrics {
  const OutboundCardMetrics({
    required this.padding,
    required this.gap,
    required this.ipTop,
    required this.cellGap,
    required this.badgeSize,
    required this.ip,
    required this.buttonSize,
    required this.buttonSlot,
    required this.decorationSize,
    required this.decorationEnd,
    required this.decorationTop,
  });

  factory OutboundCardMetrics.of(DashboardDensity density) => switch (density) {
    DashboardDensity.standard => OutboundCardMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 10,
      cellGap: 28,
      badgeSize: 48,
      ip: AppTextStyle.title1,
      buttonSize: 104,
      buttonSlot: 120,
      decorationSize: 290,
      decorationEnd: -64,
      decorationTop: -87,
    ),
    DashboardDensity.compact => OutboundCardMetrics(
      padding: dashboardCardPadding(density),
      gap: 16,
      ipTop: 8,
      cellGap: 22,
      badgeSize: 40,
      ip: AppTextStyle.title2,
      buttonSize: 84,
      buttonSlot: 100,
      decorationSize: 250,
      decorationEnd: -64,
      decorationTop: -75,
    ),
    DashboardDensity.mobile => const OutboundCardMetrics(
      padding: EdgeInsetsDirectional.fromSTEB(20, 18, 16, 18),
      gap: 10,
      ipTop: 12,
      cellGap: 24,
      badgeSize: 48,
      ip: AppTextStyle.title2,
      buttonSize: 88,
      buttonSlot: 88,
      decorationSize: 240,
      decorationEnd: -60,
      decorationTop: -66,
    ),
  };

  final EdgeInsetsGeometry padding;
  final double gap;
  final double ipTop;
  final double cellGap;
  final double badgeSize;
  final AppTextStyle ip;
  final double buttonSize;
  final double buttonSlot;
  final double decorationSize;
  final double decorationEnd;
  final double decorationTop;
}
