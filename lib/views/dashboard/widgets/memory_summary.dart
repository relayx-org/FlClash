import 'dart:math';

import 'package:fl_clash/common/num.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';

class DashboardMemorySummary extends StatelessWidget {
  const DashboardMemorySummary({
    super.key,
    this.appBytes,
    required this.coreBytes,
    required this.density,
  });

  final int? appBytes;
  final int coreBytes;
  final DashboardDensity density;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final mobile = !density.isDesktop;
    final compact = density.isCompact;
    final total = ((appBytes ?? 0) + coreBytes).traffic;
    final figure = mobile ? AppTextStyle.title1 : AppTextStyle.title2;
    final parts = [
      if (appBytes != null)
        (
          label: appLocalizations.app,
          bytes: appBytes ?? 0,
          color: colorScheme.primary,
        ),
      (
        label: appLocalizations.core,
        bytes: coreBytes,
        color: DashboardColors.of(context).series2,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: total.value,
                style: DashboardText.figure(context, figure),
              ),
              TextSpan(
                text: ' ${total.unit}',
                style: DashboardText.unit(context, AppTextStyle.footnote),
              ),
            ],
          ),
          maxLines: 1,
        ),
        if (mobile) const SizedBox(height: 14) else const Spacer(),
        DashboardMemoryBar(
          segments: [
            for (final part in parts) (bytes: part.bytes, color: part.color),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final part in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: part.color,
                      shape: AppShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 8),
                  ),
                  Text(part.label, style: DashboardText.label(context)),
                  Text(
                    '${part.bytes.traffic.value} ${part.bytes.traffic.unit}',
                    style: AppTextStyle.footnote
                        .of(context, emphasized: true)
                        .toTabular,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class DashboardMemoryBar extends StatelessWidget {
  const DashboardMemoryBar({super.key, required this.segments});

  static const _gap = 2.0;

  final List<({int bytes, Color color})> segments;

  @override
  Widget build(BuildContext context) {
    final duration = context.motionDuration(commonDuration);
    final total = segments.fold(
      0,
      (sum, segment) => sum + max(0, segment.bytes),
    );
    return ClipRSuperellipse(
      borderRadius: AppRadius.full,
      child: SizedBox(
        height: 8,
        child: total == 0
            ? ColoredBox(color: DashboardColors.of(context).tone2)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, segment) in segments.indexed) ...[
                    if (index > 0)
                      AnimatedContainer(
                        duration: duration,
                        curve: Easing.standard,
                        width:
                            segment.bytes > 0 &&
                                segments
                                    .take(index)
                                    .any((previous) => previous.bytes > 0)
                            ? _gap
                            : 0,
                      ),
                    // Whole percents, so the drift between two polls does not
                    // replay the animation every time.
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: (max(0, segment.bytes) * 100 / total)
                            .roundToDouble(),
                      ),
                      duration: duration,
                      curve: Easing.standard,
                      builder: (_, percent, child) => Expanded(
                        flex: (percent * 100).round(),
                        child: child!,
                      ),
                      child: ColoredBox(color: segment.color),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
