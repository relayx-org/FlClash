import 'dart:math' as math;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';
import 'outbound_frame.dart';

class DashboardOutboundCard extends StatelessWidget {
  const DashboardOutboundCard({
    super.key,
    required this.running,
    required this.toggle,
    required this.runTime,
    this.suspended = false,
    this.ip,
    this.countryCode,
    this.typeLabel,
    this.qualityLabel,
    this.qualityTone = DashboardChipTone.idle,
    this.organization,
    this.loading = false,
    this.failed = false,
    this.checking = false,
    this.hideIp = false,
    this.onRefresh,
    this.onDetails,
    this.action,
  });
  final bool running;
  final bool suspended;
  final String? ip;
  final String? countryCode;
  final String? typeLabel;
  final String? qualityLabel;
  final DashboardChipTone qualityTone;
  final String? organization;
  final bool loading;
  final bool failed;
  final bool checking;
  final bool hideIp;
  final VoidCallback? onRefresh;
  final VoidCallback? onDetails;
  final Widget runTime;
  final Widget toggle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final metrics = OutboundCardMetrics.of(density);
    final l = AppLocalizations.of(context);
    final (label, tone) = suspended
        ? (l.suspended, DashboardChipTone.warn)
        : running
        ? (l.running, DashboardChipTone.ok)
        : (l.notRunning, DashboardChipTone.idle);
    return OutboundCardFrame(
      running: running,
      label: l.status,
      header: DashboardCardHeader(
        glyph: AppGlyphs.status,
        title: l.status,
        leading: [DashboardChip(label: label, tone: tone, dot: running)],
      ),
      body: _ExitRow(
        ip: ip,
        countryCode: countryCode,
        failed: failed,
        loading: loading,
        checking: checking,
        onRefresh: onRefresh,
        onDetails: onDetails,
        typeLabel: typeLabel,
        qualityLabel: qualityLabel,
        qualityTone: qualityTone,
        active: running,
        metrics: metrics,
        large: !density.isDesktop,
        hideIp: hideIp,
      ),
      footer: _Cells(
        organization: organization,
        loading: loading,
        active: running && !suspended,
        gap: metrics.cellGap,
        runTime: runTime,
      ),
      toggle: toggle,
      action: action,
    );
  }
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({
    required this.ip,
    required this.countryCode,
    required this.failed,
    required this.loading,
    required this.checking,
    required this.onRefresh,
    required this.typeLabel,
    required this.qualityLabel,
    required this.qualityTone,
    required this.active,
    required this.metrics,
    required this.large,
    required this.hideIp,
    this.onDetails,
  });

  final String? ip;
  final String? countryCode;
  final bool failed;
  final bool loading;
  final bool checking;
  final VoidCallback? onRefresh;
  final String? typeLabel;
  final String? qualityLabel;
  final DashboardChipTone qualityTone;
  final bool active;
  final OutboundCardMetrics metrics;
  final bool large;
  final bool hideIp;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = DashboardText.figure(
      context,
      metrics.ip,
      color: active ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    ).copyWith(letterSpacing: 0);
    final ipAddress = this.ip;
    final appLocalizations = AppLocalizations.of(context);
    final Widget ip = ipAddress != null
        ? Tooltip(
            message: appLocalizations.details(appLocalizations.outboundIp),
            child: FocusRing(
              shape: AppShape.xs,
              standsOff: true,
              child: InkWell(
                onTap: onDetails,
                customBorder: AppShape.xs,
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: _IpText(ip: ipAddress, style: style, hideIp: hideIp),
              ),
            ),
          )
        : failed
        ? Text(
            appLocalizations.serviceFailed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: colorScheme.error),
          )
        : loading
        ? SkeletonText(width: 140, style: style)
        : Text('—', style: style);
    return Row(
      spacing: 12,
      children: [
        _CountryBadge(
          countryCode: countryCode,
          size: metrics.badgeSize,
          active: active,
          checking: checking,
          onRefresh: onRefresh,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height:
                    metrics.ip.leading * DashboardDensityScope.scaleOf(context),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ip,
                ),
              ),
              const SizedBox(height: 4),
              if (failed)
                SizedBox(
                  height: _chipHeight(large),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      appLocalizations.tapIconToRetry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.label(context),
                    ),
                  ),
                )
              else
                _IpChips(
                  typeLabel: typeLabel,
                  qualityLabel: qualityLabel,
                  tone: qualityTone,
                  loading: loading,
                  large: large,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IpText extends StatelessWidget {
  const _IpText({required this.ip, required this.style, required this.hideIp});
  final String ip;
  final TextStyle style;
  final bool hideIp;
  @override
  Widget build(BuildContext context) =>
      DashboardFitText(hideIp ? '*****' : ip, style: style);
}

double _chipHeight(bool large) => large ? 28 : 24;

const _chipSkeletonWidths = [48.0, 72.0];

class _IpChips extends StatelessWidget {
  const _IpChips({
    required this.typeLabel,
    required this.qualityLabel,
    required this.tone,
    required this.loading,
    required this.large,
  });
  final String? typeLabel;
  final String? qualityLabel;
  final DashboardChipTone tone;
  final bool loading;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final height = _chipHeight(large);
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Wrap(
          spacing: 6,
          runSpacing: height,
          children: [
            if (typeLabel != null) ...[
              DashboardChip(label: typeLabel!, large: large),
              if (qualityLabel != null)
                DashboardChip(label: qualityLabel!, tone: tone, large: large),
            ] else if (loading) ...[
              for (final width in _chipSkeletonWidths)
                SkeletonPill(width: width, height: height),
            ] else
              DashboardChip(
                label: AppLocalizations.of(context).ipTypeUnknown,
                large: large,
              ),
          ],
        ),
      ),
    );
  }
}

const _spinPeriod = Duration(milliseconds: 1500);

/// The exit's country on a clover that checks the exit again when tapped and
/// turns while it is being checked.
class _CountryBadge extends StatefulWidget {
  const _CountryBadge({
    required this.countryCode,
    required this.size,
    required this.active,
    required this.checking,
    required this.onRefresh,
  });

  final String? countryCode;
  final double size;
  final bool active;
  final bool checking;
  final VoidCallback? onRefresh;

  @override
  State<_CountryBadge> createState() => _CountryBadgeState();
}

class _CountryBadgeState extends State<_CountryBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  );
  var _hovered = false;
  var _focused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spin();
  }

  @override
  void didUpdateWidget(_CountryBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checking != widget.checking) {
      _spin();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  void _spin() {
    if (context.disableAnimations) {
      _turns.value = 0;
    } else if (widget.checking) {
      _turns.repeat();
    } else {
      // A clover looks the same every quarter turn, so it stops on the next.
      final rest = (_turns.value * 4).ceil() / 4;
      _turns.animateTo(rest, duration: _spinPeriod * (rest - _turns.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foreground = widget.active
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final enabled = !widget.checking && widget.onRefresh != null;
    final size = widget.size;
    final code = widget.countryCode;
    final tooltip = AppLocalizations.of(context).retry;
    final color = Color.alphaBlend(
      foreground.withValues(alpha: enabled && _hovered ? 0.08 : 0),
      DashboardColors.of(context).tone2,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkResponse(
          onTap: enabled ? widget.onRefresh : null,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          child: ElasticPress(
            enabled: enabled,
            child: AnimatedBuilder(
              animation: _turns,
              builder: (_, child) => ShapeBadge(
                shape: MaterialShapes.clover4Leaf,
                color: color,
                size: size,
                rotation: _turns.value * 2 * math.pi,
                ring: _focused ? focusRingSide(colorScheme) : null,
                child: child,
              ),
              child: code == null || code.isEmpty
                  ? GlyphIcon(
                      AppGlyphs.proxies,
                      size: size * 0.42,
                      color: foreground,
                    )
                  : Text(
                      code.toUpperCase(),
                      maxLines: 1,
                      style: AppTextStyle.footnote
                          .of(context, emphasized: true)
                          .copyWith(
                            color: foreground,
                            letterSpacing: 0.04 * AppTextStyle.footnote.size,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells({
    required this.organization,
    required this.loading,
    required this.active,
    required this.gap,
    required this.runTime,
  });

  final String? organization;
  final bool loading;
  final bool active;
  final double gap;
  final Widget runTime;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    return Row(
      spacing: gap,
      children: [
        _Cell(
          label: appLocalizations.runTime,
          value: active ? runTime : const _Placeholder(),
        ),
        Flexible(
          child: _Cell(
            label: appLocalizations.ipOrganization,
            value: organization != null
                ? _CellText(organization!)
                : loading
                ? SkeletonText(width: 96, style: _cellStyle(context))
                : const _Placeholder(),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        const SizedBox(height: 2),
        value,
      ],
    );
  }
}

TextStyle _cellStyle(BuildContext context) =>
    AppTextStyle.subheadline.of(context, emphasized: true).toTabular;

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _cellStyle(context),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Text('—', maxLines: 1, style: _cellStyle(context));
  }
}
