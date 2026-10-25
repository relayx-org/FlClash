import 'dart:math' as math;

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'site_config.dart';
import 'brand.dart';

class IpingLoginLayout extends StatelessWidget {
  const IpingLoginLayout({super.key, required this.site, required this.child});

  final IpingSiteConfig site;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) >=
            960;
        final inset = wide ? 32.0 : 16.0;
        final level = context.raisedSurfaceLevel;
        final account = DecoratedBox(
          decoration: ShapeDecoration(
            color: level.colorOf(context.colorScheme),
            shape: AppShape.all(AppCorner.xxl),
          ),
          child: SurfaceScope(
            level: level,
            child: Padding(
              padding: EdgeInsets.all(wide ? 40 : 24),
              child: child,
            ),
          ),
        );
        final brand = _BrandPanel(
          site: site,
          wide: wide,
          condensed: !wide && constraints.maxHeight < 700,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - inset * 2),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1280 : 540),
                child: wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 11, child: brand),
                            const SizedBox(width: 24),
                            Expanded(flex: 10, child: Center(child: account)),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [brand, const SizedBox(height: 16), account],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.site,
    required this.wide,
    required this.condensed,
  });

  final IpingSiteConfig site;
  final bool wide;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final background = dark
        ? context.raisedSurfaceLevel.colorOf(scheme)
        : scheme.inverseSurface;
    final foreground = dark ? scheme.onSurface : scheme.onInverseSurface;
    final accent = scheme.primaryFixedDim;
    final muted = foreground.withValues(alpha: 0.7);
    final heading = wide ? AppTextStyle.display : AppTextStyle.title1;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: AppShape.all(AppCorner.xxl),
      ),
      child: Padding(
        padding: EdgeInsets.all(wide ? 40 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IpingLogo(src: site.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    site.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.title2
                        .of(context, emphasized: true)
                        .copyWith(color: foreground),
                  ),
                ),
                const SizedBox(width: 12),
                GlyphIcon(AppGlyphs.proxies, color: muted, size: 24),
              ],
            ),
            if (!condensed || site.description.isNotEmpty)
              SizedBox(height: wide ? 56 : 24),
            if (wide) ...[
              Text(
                l.ipingBrandEyebrow,
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: accent),
              ),
              const SizedBox(height: 16),
            ],
            if (!condensed) ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${l.ipingBrandHeadline}\n'),
                    TextSpan(
                      text: l.ipingBrandHeadlineAccent,
                      style: TextStyle(color: accent),
                    ),
                  ],
                ),
                style: heading
                    .of(context, emphasized: true)
                    .copyWith(color: foreground),
              ),
              const SizedBox(height: 16),
            ],
            if (!condensed || site.description.isNotEmpty)
              Text(
                site.description.isEmpty
                    ? l.ipingBrandDescription
                    : site.description,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: muted),
              ),
            if (wide) ...[
              const SizedBox(height: 32),
              _ConnectionIllustration(
                background: background,
                foreground: foreground,
                accent: accent,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  for (final (glyph, label) in [
                    (AppGlyphs.lock, l.ipingFeatureLogin),
                    (AppGlyphs.sync, l.ipingFeatureSync),
                    (AppGlyphs.proxies, l.ipingFeatureConnect),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlyphIcon(glyph, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: AppTextStyle.caption1
                              .of(context)
                              .copyWith(color: foreground),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionIllustration extends StatelessWidget {
  const _ConnectionIllustration({
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color accent;

  Widget _endpoint(BuildContext context, Glyph glyph, String label) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlyphIcon(glyph, color: accent, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ConnectionPainter(accent)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _endpoint(context, AppGlyphs.devices, l.ipingDevice),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _endpoint(context, AppGlyphs.proxies, l.ipingNetwork),
            ),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: Color.alphaBlend(
                  foreground.withValues(alpha: 0.08),
                  background,
                ),
                shape: AppShape.full,
              ),
              child: SizedBox.square(
                dimension: 104,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlyphIcon(AppGlyphs.connections, color: accent, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      l.ipingGateway,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width * 0.29, size.height * 0.44);
    final grid = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, grid);
    for (final scale in [0.38, 0.72]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * scale,
          height: radius * 2,
        ),
        grid,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2 * scale,
        ),
        grid,
      );
    }
    final route = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final direction in [-1, 1]) {
      final bend = size.height * 0.32 * direction;
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.08, center.dy)
          ..cubicTo(
            size.width * 0.34,
            center.dy + bend,
            size.width * 0.66,
            center.dy - bend,
            size.width * 0.92,
            center.dy,
          ),
        route,
      );
    }
    final node = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.34, center.dy - 20), 3, node);
    canvas.drawCircle(Offset(size.width * 0.66, center.dy + 20), 3, node);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) =>
      oldDelegate.color != color;
}
