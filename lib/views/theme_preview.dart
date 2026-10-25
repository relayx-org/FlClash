import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/ui/appearance_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

export 'package:fl_clash/ui/appearance_preview.dart';

class ThemeLivePreview extends ConsumerWidget {
  const ThemeLivePreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    return AppearancePreview(
      colorScheme: ref.watch(genColorSchemeProvider(brightness)),
      floatingBar: ref.watch(
        appSettingProvider.select((state) => state.floatingNavigationBar),
      ),
      tabAnimation: ref.watch(
        appSettingProvider.select((state) => state.tabAnimation),
      ),
      liquidGlass: ref.watch(
        themeSettingProvider.select(
          (state) => state.liquidGlass != LiquidGlassMode.none,
        ),
      ),
    );
  }
}
