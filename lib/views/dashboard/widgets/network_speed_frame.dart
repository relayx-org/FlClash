import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../common/num.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/ui.dart';
import '../../../ui/icons/icons.dart';
import '../layout.dart';
import '../style.dart';
import 'card.dart';
import 'speed_frame.dart';

class NetworkSpeedFrame extends StatelessWidget {
  const NetworkSpeedFrame({
    super.key,
    required this.upload,
    required this.download,
  });
  final Widget upload;
  final Widget download;
  @override
  Widget build(BuildContext context) => DashboardCard(
    semanticLabel: AppLocalizations.of(context).networkSpeed,
    child: Column(
      children: [
        DashboardCardHeader(
          glyph: AppGlyphs.speed,
          title: AppLocalizations.of(context).networkSpeed,
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 10,
          children: [
            Expanded(child: upload),
            Expanded(child: download),
          ],
        ),
      ],
    ),
  );
}

class NetworkSpeedTile extends StatelessWidget {
  const NetworkSpeedTile({
    super.key,
    required this.upload,
    required this.speed,
    required this.total,
    required this.values,
    required this.revision,
    required this.capacity,
  });
  final bool upload;
  final num speed;
  final num total;
  final List<double> values;
  final int revision;
  final int capacity;

  static const _aspectRatio = 1.06;
  static const _padding = EdgeInsets.fromLTRB(16, 14, 16, 0);
  static const _titleGap = 4.0;
  static const _chartGap = 12.0;
  static const _bleed = 2.0;
  static const _minChartHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final color = upload
        ? context.colorScheme.onSurfaceVariant
        : context.colorScheme.primary;
    final show = speed.traffic;
    final scale = DashboardDensityScope.scaleOf(context);
    final textHeight =
        _padding.top +
        _titleGap +
        (AppTextStyle.footnote.leading +
                AppTextStyle.title1.leading +
                AppTextStyle.caption1.leading) *
            scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = math.max(
          _minChartHeight,
          constraints.maxWidth / _aspectRatio - textHeight - _chartGap + _bleed,
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: DashboardColors.of(context).tone,
            shape: AppShape.all(DashboardCorner.mobileBlock),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -_bleed,
                right: -_bleed,
                bottom: -_bleed,
                height: chartHeight,
                child: RepaintBoundary(
                  child: LineChart(
                    values: values,
                    revision: revision,
                    capacity: capacity,
                    minScale: 8192,
                    baselineRatio: 1,
                    color: upload
                        ? DashboardColors.of(context).series2
                        : context.colorScheme.primary,
                  ),
                ),
              ),
              Padding(
                padding: _padding.copyWith(
                  bottom: chartHeight - _bleed + _chartGap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 4,
                      children: [
                        GlyphIcon(
                          upload ? AppGlyphs.arrowUp : AppGlyphs.arrowDown,
                          size: 16,
                          color: color,
                        ),
                        Flexible(
                          child: Text(
                            upload
                                ? AppLocalizations.of(context).upload
                                : AppLocalizations.of(context).download,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.footnote
                                .of(context, emphasized: true)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _titleGap),
                    DashboardTrafficFigure(
                      value: show.value,
                      unit: '${show.unit}/s',
                      style: AppTextStyle.title1,
                      unitStyle: AppTextStyle.footnote,
                    ),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).trafficTotal(dashboardTraffic(total)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.label(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
