import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

const _chartBleed = 3.0;

class DashboardTrafficFigure extends StatelessWidget {
  const DashboardTrafficFigure({
    super.key,
    required this.value,
    required this.unit,
    required this.style,
    required this.unitStyle,
  });

  final String value;
  final String unit;
  final AppTextStyle style;
  final AppTextStyle unitStyle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: DashboardText.figure(context, style)),
          TextSpan(
            text: ' $unit',
            style: DashboardText.unit(context, unitStyle),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}

class DashboardSpeedFrame extends StatelessWidget {
  const DashboardSpeedFrame({
    super.key,
    required this.title,
    required this.glyph,
    required this.glyphColor,
    required this.peakLabel,
    required this.totalLabel,
    required this.figure,
    required this.chart,
  });

  final String title;
  final Glyph glyph;
  final Color glyphColor;
  final String peakLabel;
  final String totalLabel;
  final Widget figure;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final padding = dashboardCardPadding(density);
    return DashboardCard(
      padding: EdgeInsets.zero,
      semanticLabel: title,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: -_chartBleed,
            right: -_chartBleed,
            bottom: -_chartBleed,
            height: compact ? 62 : 88,
            child: RepaintBoundary(child: chart),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24 * scale,
                  child: Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(glyph, size: 18, color: glyphColor),
                      Text(
                        title,
                        maxLines: 1,
                        style: DashboardText.cardTitle(context),
                      ),
                      Expanded(
                        child: Text(
                          peakLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: DashboardText.label(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 6 : 10),
                figure,
                const SizedBox(height: 2),
                Text(
                  totalLabel,
                  maxLines: 1,
                  style: DashboardText.label(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
