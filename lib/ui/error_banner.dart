import 'package:material_ui/material_ui.dart';
import 'ui.dart';
import 'icons/icons.dart';

class ErrorBanner extends StatelessWidget {
  final String? message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final message = this.message;
    return AnimatedSize(
      duration: commonDuration,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : _Banner(
              glyph: AppGlyphs.error,
              message: message,
              color: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Glyph glyph;
  final String message;
  final Color color;
  final Color foregroundColor;

  const _Banner({
    required this.glyph,
    required this.message,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(color: color, shape: AppShape.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          GlyphIcon(glyph, size: 20.ap(context), color: foregroundColor),
          Expanded(
            child: Text(
              message,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
