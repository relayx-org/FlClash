import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'account_statistics.dart';
import 'topup.dart';

String _day(DateTime date) => date.toIso8601String().substring(0, 10);

class IpingRenewalWarning extends StatelessWidget {
  const IpingRenewalWarning({
    super.key,
    required this.count,
    required this.cost,
    required this.shortfall,
    required this.onTopUp,
  });

  final int count;
  final double cost;
  final double shortfall;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final foreground = scheme.onWarningContainer;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.warningContainer,
        shape: AppShape.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          spacing: 12,
          children: [
            GlyphIcon(
              AppGlyphs.warning,
              size: 20.ap(context),
              color: foreground,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    l.ipingRenewalShortfall,
                    style: AppTextStyle.subheadline
                        .of(context, emphasized: true)
                        .copyWith(color: foreground),
                  ),
                  Text(
                    l.ipingRenewalShortfallDetail(
                      count,
                      ipingCurrency(cost),
                      ipingCurrency(shortfall),
                    ),
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: foreground),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTopUp,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(l.ipingTopUp),
            ),
          ],
        ),
      ),
    );
  }
}

class IpingReferralSection extends StatelessWidget {
  const IpingReferralSection({super.key, required this.stats});

  final IpingReferralStats stats;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: stats.link));
    if (!context.mounted) return;
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }

  Widget _value(BuildContext context, String title, String value) => ListItem(
    title: Text(title),
    trailing: Text(
      value,
      style: context.listTitleStyle.toTabular.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return generateSection(
      title: l.ipingReferralInformation,
      footer: l.ipingReferralHint,
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(l.ipingReferralLink),
          subtitle: Text(
            stats.link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: l.copyLink,
            onPressed: () => _copy(context),
            icon: const GlyphIcon(AppGlyphs.copy),
          ),
          onTap: () => _copy(context),
        ),
        _value(context, l.ipingReferralCount, '${stats.count}'),
        _value(context, l.ipingReferralEarnings, ipingCurrency(stats.earnings)),
        _value(
          context,
          l.ipingReferralRate,
          '${stats.commissionRate.fixed()}%',
        ),
      ],
    );
  }
}

/// The billed series alone: it is what the allowance and the balance pay for.
class IpingTrafficChart extends StatefulWidget {
  const IpingTrafficChart({super.key, required this.stats});

  final IpingTrafficStats stats;

  @override
  State<IpingTrafficChart> createState() => _IpingTrafficChartState();
}

class _IpingTrafficChartState extends State<IpingTrafficChart> {
  int? _selected;

  int _indexAt(double dx, double width) {
    final count = widget.stats.days.length;
    return (dx / width * count).floor().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final days = widget.stats.days;
    final empty = days.every((day) => day.billed <= 0 && day.actual <= 0);
    final selected = _selected == null || _selected! >= days.length
        ? null
        : days[_selected!];
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: scheme.onSurfaceVariant);
    final axis = AppTextStyle.caption2
        .of(context)
        .toTabular
        .copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(title: l.ipingTraffic30Days),
        CommonCard(
          radius: AppCorner.xl,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: empty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l.ipingNoTraffic,
                    textAlign: TextAlign.center,
                    style: secondary,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected == null
                                    ? l.ipingBilledTraffic
                                    : '${_day(selected.date)} · '
                                          '${l.ipingBilledTraffic}',
                                style: secondary,
                              ),
                              Text(
                                ipingGigabytes(
                                  selected?.billed ?? widget.stats.billed,
                                ),
                                style: AppTextStyle.title2
                                    .of(context, emphasized: true)
                                    .toTabular
                                    .copyWith(color: scheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(l.ipingActualTraffic, style: secondary),
                            Text(
                              ipingGigabytes(
                                selected?.actual ?? widget.stats.actual,
                              ),
                              style: AppTextStyle.subheadline
                                  .of(context)
                                  .toTabular
                                  .copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 128,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          return MouseRegion(
                            onHover: (event) => setState(
                              () => _selected = _indexAt(
                                event.localPosition.dx,
                                width,
                              ),
                            ),
                            onExit: (_) => setState(() => _selected = null),
                            child: GestureDetector(
                              key: const ValueKey('iping-traffic-bars'),
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                final index = _indexAt(
                                  details.localPosition.dx,
                                  width,
                                );
                                setState(
                                  () => _selected = _selected == index
                                      ? null
                                      : index,
                                );
                              },
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: _TrafficBarsPainter(
                                  values: [for (final day in days) day.billed],
                                  selected: _selected,
                                  color: scheme.primary,
                                  baseline: scheme.outlineVariant,
                                  labelStyle: axis,
                                  selectedLabelStyle: AppTextStyle.caption2
                                      .of(context, emphasized: true)
                                      .toTabular
                                      .copyWith(color: scheme.onSurface),
                                  textScaler: MediaQuery.textScalerOf(context),
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_day(days.first.date).substring(5), style: axis),
                        Text(_day(days.last.date).substring(5), style: axis),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TrafficBarsPainter extends CustomPainter {
  _TrafficBarsPainter({
    required this.values,
    required this.selected,
    required this.color,
    required this.baseline,
    required this.labelStyle,
    required this.selectedLabelStyle,
    required this.textScaler,
    required this.textDirection,
  });

  static const _corner = 4.0;
  static const _minHeight = 2.0;
  static const _dimmed = 0.35;
  static const _labelGap = 3.0;
  static const _labelSpacing = 4.0;

  final List<double> values;
  final int? selected;
  final Color color;
  final Color baseline;
  final TextStyle labelStyle;
  final TextStyle selectedLabelStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;

  TextPainter _label(int index) => TextPainter(
    text: TextSpan(
      text: values[index].fixed(decimals: 1),
      style: index == selected ? selectedLabelStyle : labelStyle,
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.fold(0.0, math.max);
    final slot = size.width / values.length;
    final barWidth = math.min(slot - 2, math.max(2.0, slot * 0.62));
    final bottom = size.height - 1;
    final probe = _label(0);
    final reserved = probe.height + _labelGap;
    probe.dispose();
    final active = Paint()..color = color;
    final dimmed = Paint()..color = color.withValues(alpha: color.a * _dimmed);
    final bars = <int, Rect>{};
    for (final (index, value) in values.indexed) {
      if (value <= 0 || top <= 0) continue;
      final height = math.max(
        _minHeight,
        value / top * math.max(0.0, bottom - reserved),
      );
      final left = slot * index + (slot - barWidth) / 2;
      final rect = Rect.fromLTWH(left, bottom - height, barWidth, height);
      bars[index] = rect;
      final corner = math.min(_corner, barWidth / 2);
      canvas.drawRSuperellipse(
        AppRadius.top(corner).toRSuperellipse(rect),
        selected == null || selected == index ? active : dimmed,
      );
    }
    _paintLabels(canvas, size, bars);
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  /// Labels the selected bar first, then the tallest bars wherever a label
  /// still fits without touching one already placed.
  void _paintLabels(Canvas canvas, Size size, Map<int, Rect> bars) {
    final order = bars.keys.toList()
      ..sort((a, b) {
        if (a == selected) return -1;
        if (b == selected) return 1;
        return values[b].compareTo(values[a]);
      });
    final placed = <Rect>[];
    for (final index in order) {
      final painter = _label(index);
      final bar = bars[index]!;
      final left = (bar.center.dx - painter.width / 2)
          .clamp(0.0, math.max(0.0, size.width - painter.width))
          .toDouble();
      final area = Rect.fromLTWH(
        left,
        bar.top - _labelGap - painter.height,
        painter.width,
        painter.height,
      );
      if (!placed.any(area.inflate(_labelSpacing / 2).overlaps)) {
        painter.paint(canvas, area.topLeft);
        placed.add(area);
      }
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_TrafficBarsPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.selected != selected ||
      oldDelegate.color != color ||
      oldDelegate.baseline != baseline ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.selectedLabelStyle != selectedLabelStyle ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection;
}
