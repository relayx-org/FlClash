import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/enum/mode.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

List<({Mode value, String label, Glyph glyph})> _modesOf(BuildContext context) {
  final l = AppLocalizations.of(context);
  return [
    (value: Mode.rule, label: l.rule, glyph: AppGlyphs.rules),
    (value: Mode.global, label: l.global, glyph: AppGlyphs.proxies),
    (value: Mode.direct, label: l.direct, glyph: AppGlyphs.target),
  ];
}

class DashboardModeCard extends StatelessWidget {
  const DashboardModeCard({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final Mode mode;
  final ValueChanged<Mode>? onChanged;

  static const _outer = 26.0;

  @override
  Widget build(BuildContext context) {
    final tone = DashboardColors.of(context).tone;
    final style = AppTextStyle.footnote.of(context, emphasized: true);
    return DashboardCard(
      semanticLabel: AppLocalizations.of(context).outboundMode,
      child: Column(
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.split,
            title: AppLocalizations.of(context).outboundMode,
          ),
          const SizedBox(height: 12),
          DashboardConnectedGroup(
            children: [
              for (final (index, item) in _modesOf(context).indexed)
                Expanded(
                  child: DashboardConnectedButton(
                    selected: item.value == mode,
                    first: index == 0,
                    last: index == 3 - 1,
                    outer: _outer,
                    inner: 12,
                    background: tone,
                    semanticLabel: item.label,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(item.value),
                    builder: (foreground) => SizedBox(
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 2,
                        children: [
                          GlyphIcon(item.glyph, size: 18, color: foreground),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.copyWith(color: foreground),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The desktop control row's mode switch; its buttons sit as far in from the
/// card's ends as from its edges so their corners stay concentric.
class DashboardModeBar extends StatelessWidget {
  const DashboardModeBar({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final Mode mode;
  final ValueChanged<Mode>? onChanged;

  static const _inset = 8.0;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final appLocalizations = AppLocalizations.of(context);
    final outer = dashboardCardRadius(density) - _inset;
    final style = AppTextStyle.subheadline.of(context, emphasized: true);
    return DashboardCard(
      semanticLabel: appLocalizations.outboundMode,
      padding: EdgeInsetsDirectional.fromSTEB(
        dashboardCardPadding(density).left,
        _inset,
        _inset,
        _inset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          spacing: 16,
          children: [
            GlyphIcon(
              AppGlyphs.split,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 4),
              child: Text(
                appLocalizations.outboundMode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.cardTitle(context),
              ),
            ),
            Expanded(
              child: DashboardConnectedGroup(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, item) in _modesOf(context).indexed)
                    Expanded(
                      child: DashboardConnectedButton(
                        selected: item.value == mode,
                        first: index == 0,
                        last: index == 3 - 1,
                        outer: outer,
                        inner: 10,
                        background: DashboardColors.of(context).tone,
                        semanticLabel: item.label,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(item.value),
                        builder: (foreground) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 6,
                          children: [
                            GlyphIcon(item.glyph, size: 18, color: foreground),
                            Flexible(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style.copyWith(color: foreground),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
