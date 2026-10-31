import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

const ipingCardCorner = AppCorner.xl;
const ipingCardPadding = EdgeInsets.all(16);
const ipingCardGap = 12.0;
const ipingMarkSize = 40.0;

class IpingCardMark extends StatelessWidget {
  const IpingCardMark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox.square(
      dimension: ipingMarkSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(scheme),
          shape: AppShape.md,
        ),
        child: IconTheme.merge(
          data: IconThemeData(size: 20, color: scheme.onSurfaceVariant),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The filter chip of the iPing store lists. A tag tone keeps its own colors;
/// any other chosen chip takes primary.
class IpingPill extends StatelessWidget {
  const IpingPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.glyph,
    this.trailing,
    this.color,
    this.foregroundColor,
  });

  const IpingPill.removable({
    super.key,
    required this.label,
    required this.onPressed,
  }) : selected = false,
       glyph = null,
       trailing = const GlyphIcon(AppGlyphs.close, size: 12),
       color = null,
       foregroundColor = null;

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final Glyph? glyph;
  final Widget? trailing;
  final Color? color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (background, foreground) = selected
        ? foregroundColor == null
              ? (scheme.primary, scheme.onPrimary)
              : (foregroundColor!, scheme.surface)
        : (
            color ?? context.raisedSurfaceLevel.colorOf(scheme),
            foregroundColor ?? scheme.onSurfaceVariant,
          );
    return Semantics(
      button: true,
      selected: selected,
      child: FocusRing(
        shape: AppShape.full,
        standsOff: selected,
        child: Material(
          color: background,
          shape: AppShape.full,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: AppShape.full,
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                glyph == null ? 12 : 10,
                7,
                trailing == null ? 12 : 8,
                7,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 5,
                  children: [
                    if (glyph != null) GlyphIcon(glyph!, size: 14),
                    Text(
                      label,
                      maxLines: 1,
                      style: AppTextStyle.footnote
                          .of(context, emphasized: selected)
                          .copyWith(color: foreground),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
