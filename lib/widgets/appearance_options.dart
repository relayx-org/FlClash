import 'package:material_ui/material_ui.dart';

import '../ui/appearance.dart';
import '../l10n/l10n.dart';
import '../ui/appearance_preview.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

class ThemeModeChoice extends StatelessWidget {
  const ThemeModeChoice({
    super.key,
    required this.value,
    required this.lightScheme,
    required this.darkScheme,
    required this.floatingBar,
    required this.liquidGlass,
    required this.onChanged,
  });
  final ThemeMode value;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final bool floatingBar;
  final bool liquidGlass;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final light = MiniScreen(
      colorScheme: lightScheme,
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    final dark = MiniScreen(
      colorScheme: darkScheme,
      floatingBar: floatingBar,
      liquidGlass: liquidGlass,
    );
    return PreviewChoiceGroup<ThemeMode>(
      info: Info(label: appLocalizations.themeMode, glyph: AppGlyphs.sun),
      value: value,
      choices: [
        PreviewChoice(
          value: ThemeMode.system,
          label: appLocalizations.auto,
          pictogram: MiniScreenThumb(
            screen: MiniSplitScreen(light: light, dark: dark),
          ),
        ),
        PreviewChoice(
          value: ThemeMode.light,
          label: appLocalizations.light,
          pictogram: MiniScreenThumb(screen: light),
        ),
        PreviewChoice(
          value: ThemeMode.dark,
          label: appLocalizations.dark,
          pictogram: MiniScreenThumb(screen: dark),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class LiquidGlassChoice extends StatelessWidget {
  const LiquidGlassChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final LiquidGlassMode value;
  final ValueChanged<LiquidGlassMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    // Floating either way, as a docked bar stays a fill, over the list page,
    // whose rows run on under the bar where glass shows them.
    Widget preview(bool liquidGlass) => MiniScreenThumb(
      screen: MiniScreen(
        colorScheme: colorScheme,
        floatingBar: true,
        liquidGlass: liquidGlass,
        selected: 1,
      ),
    );
    return PreviewChoiceGroup<LiquidGlassMode>(
      info: Info(
        label: appLocalizations.liquidGlass,
        glyph: AppGlyphs.liquidGlass,
      ),
      value: value,
      choices: [
        PreviewChoice(
          value: LiquidGlassMode.none,
          label: appLocalizations.none,
          pictogram: preview(false),
        ),
        PreviewChoice(
          value: LiquidGlassMode.standard,
          label: appLocalizations.standard,
          pictogram: preview(true),
        ),
        PreviewChoice(
          value: LiquidGlassMode.ultra,
          label: appLocalizations.ultra,
          pictogram: preview(true),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
