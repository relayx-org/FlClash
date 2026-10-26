import 'dart:math' as math;
import 'package:fl_clash/common/datetime.dart';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

typedef DashboardProfileUsage = ({int used, int total, double share});
int _daysLeft(DateTime expiry) =>
    math.max(0, expiry.difference(DateTime.now()).inDays);
String _expiryText(BuildContext context, DateTime expiry) =>
    AppLocalizations.of(
      context,
    ).profileExpiresIn(expiry.show, _daysLeft(expiry));
const _nearlyUsedShare = 0.9;
String _percentOf(double share) => '${(share * 100).round()}%';
const _rowGap = 12.0;
double _widthOf(BuildContext context, String text, TextStyle style) =>
    MeasureScope.of(context).computeTextSize(Text(text, style: style)).width;

class DashboardProfileCard extends StatelessWidget {
  const DashboardProfileCard({
    super.key,
    required this.name,
    required this.onDetails,
    required this.summary,
    this.source,
    this.updatedAt,
    this.expiry,
    this.usage,
    this.sync,
  });
  final String? name;
  final String? source;
  final DateTime? updatedAt;
  final DateTime? expiry;
  final DashboardProfileUsage? usage;
  final Widget summary;
  final Widget? sync;
  final VoidCallback onDetails;

  static const _soonDays = 7;

  @override
  Widget build(BuildContext context) {
    final usage = this.usage;
    final density = DashboardDensityScope.of(context);
    final mobile = !density.isDesktop;
    final compact = density.isCompact;
    final appLocalizations = AppLocalizations.of(context);
    final label = DashboardText.label(context);
    final figure = mobile
        ? AppTextStyle.title3
        : (compact ? AppTextStyle.callout : AppTextStyle.headline);
    final nameStyle = mobile || !compact
        ? AppTextStyle.headline
        : AppTextStyle.callout;
    final endText = expiry != null
        ? appLocalizations.profileDaysLeft(_daysLeft(expiry!))
        : source;
    final Widget? end = switch ((endText, expiry)) {
      (final text?, final expiry?) => Tooltip(
        message: _expiryText(context, expiry),
        child: Text(
          text,
          maxLines: 1,
          style: _daysLeft(expiry) <= _soonDays
              ? label.copyWith(color: DashboardColors.of(context).warn)
              : label,
        ),
      ),
      (final text?, null) => Text(text, maxLines: 1, style: label),
      _ => null,
    };
    final nameRow = Row(
      children: [
        Flexible(
          child: EmojiText(
            name ?? appLocalizations.subscriptionInfo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle.of(context, emphasized: true),
          ),
        ),
      ],
    );
    return DashboardCard(
      semanticLabel: appLocalizations.profile,
      onTap: mobile || name == null ? onDetails : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.profiles,
            title: appLocalizations.profile,
            chevron: mobile,
            trailing: [
              if (mobile)
                ?sync
              else
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?sync,
                      DashboardIconButton(
                        glyph: AppGlyphs.chevronForward,
                        tooltip: appLocalizations.details(
                          appLocalizations.profile,
                        ),
                        onPressed: onDetails,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: mobile ? 12 : 10),
          if (compact && end != null)
            DashboardCappedRow(spacing: _rowGap, start: nameRow, end: end)
          else
            nameRow,
          if (name != null && !compact)
            LayoutBuilder(
              builder: (context, constraints) {
                final time = updatedAt?.getLastUpdateTimeDesc(context);
                final updated = time == null
                    ? null
                    : appLocalizations.profileUpdatedAt(time);
                final fits =
                    updated == null ||
                    _widthOf(context, updated, label) +
                            _rowGap +
                            _widthOf(context, endText ?? '', label) <=
                        constraints.maxWidth;
                return Row(
                  spacing: _rowGap,
                  children: [
                    Expanded(
                      child: Text(
                        (fits ? updated : time) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ),
                    ?end,
                  ],
                );
              },
            ),
          if (name != null) ...[
            if (mobile) const SizedBox(height: 14) else const Spacer(),
            if (usage != null)
              _UsageMeter(usage: usage, figure: figure, gap: mobile ? 8 : 6)
            else
              summary,
          ],
        ],
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({
    required this.usage,
    required this.figure,
    required this.gap,
  });

  final DashboardProfileUsage usage;
  final AppTextStyle figure;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final percent = DashboardText.figure(
              context,
              figure,
            ).copyWith(letterSpacing: 0);
            final unit = DashboardText.unit(context, AppTextStyle.footnote);
            final used = ' ${AppLocalizations.of(context).usedShort}';
            final traffic =
                '${dashboardTraffic(usage.used)} / ${dashboardTraffic(usage.total)}';
            final trafficStyle = AppTextStyle.footnote
                .of(context)
                .toTabular
                .copyWith(color: context.colorScheme.onSurfaceVariant);
            final showUnit =
                _widthOf(context, _percentOf(usage.share), percent) +
                    _widthOf(context, used, unit) +
                    _rowGap +
                    _widthOf(context, traffic, trafficStyle) <=
                constraints.maxWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: _rowGap,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: _percentOf(usage.share), style: percent),
                      if (showUnit) TextSpan(text: used, style: unit),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    traffic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: trafficStyle,
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: gap),
        SizedBox(
          height: 12,
          child: CustomPaint(
            painter: _WavyProgressPainter(
              value: usage.share,
              active: usage.share >= _nearlyUsedShare
                  ? DashboardColors.of(context).warn
                  : context.colorScheme.primary,
              track: DashboardColors.of(context).tone2,
            ),
          ),
        ),
      ],
    );
  }
}

/// The M3 Expressive wavy linear indicator: a wave up to [value], a gap,
/// then a flat track ending in a stop dot.
class _WavyProgressPainter extends CustomPainter {
  const _WavyProgressPainter({
    required this.value,
    required this.active,
    required this.track,
  });

  static const _stroke = 4.0;
  static const _amplitude = 3.0;
  static const _wavelength = 12.0;
  static const _gap = 6.0;
  static const _stop = 4.0;

  final double value;
  final Color active;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const start = _stroke / 2;
    final end = size.width - _stroke / 2;
    final split = start + (end - start) * value;
    final paint = Paint()
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (value > 0) {
      final wave = Path()..moveTo(start, mid);
      for (var x = start; x <= split; x += 1) {
        wave.lineTo(
          x,
          mid + _amplitude * math.sin((x - start) / _wavelength * 2 * math.pi),
        );
      }
      canvas.drawPath(wave, paint..color = active);
    }
    final trackStart = value > 0 ? split + _gap + _stroke : start;
    if (trackStart < end - _stop) {
      canvas.drawLine(
        Offset(trackStart, mid),
        Offset(end - _stop - _gap, mid),
        paint..color = track,
      );
    }
    if (value < 1) {
      canvas.drawCircle(
        Offset(end - _stop / 2, mid),
        _stop / 2,
        Paint()..color = active,
      );
    }
  }

  @override
  bool shouldRepaint(_WavyProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.active != active ||
      oldDelegate.track != track;
}

class DashboardConfigStats extends StatelessWidget {
  const DashboardConfigStats({
    super.key,
    this.groups,
    this.proxies,
    this.rules,
    this.failed = false,
  });
  final int? groups;
  final int? proxies;
  final int? rules;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final style = !density.isDesktop
        ? AppTextStyle.title3
        : density.isCompact
        ? AppTextStyle.callout
        : AppTextStyle.headline;
    final appLocalizations = AppLocalizations.of(context);
    final figure = DashboardText.figure(
      context,
      style,
    ).copyWith(letterSpacing: 0);
    final label = DashboardText.label(context);
    Widget item(int? value, String name) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value != null)
          Text(dashboardCount(value), maxLines: 1, style: figure)
        else if (failed)
          Text('—', maxLines: 1, style: figure)
        else
          SkeletonText(width: style.size * 1.5, style: figure),
        Text(name, maxLines: 1, style: label),
      ],
    );
    return LayoutBuilder(
      // The minimum width lets spaceBetween spread the row inside FittedBox.
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 16,
            children: [
              item(groups, appLocalizations.proxyGroup),
              item(proxies, appLocalizations.proxies),
              item(rules, appLocalizations.rules),
            ],
          ),
        ),
      ),
    );
  }
}
