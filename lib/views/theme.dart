import 'package:fl_clash/widgets/appearance_controls.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/settings_page.dart';
import 'package:fl_clash/views/font_family.dart';
import 'package:fl_clash/views/theme_preview.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeView extends ConsumerWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeSettingProvider);
    return AppearanceSettingsPage(
      mode: theme.themeMode,
      lightScheme: ref.watch(genColorSchemeProvider(Brightness.light)),
      darkScheme: ref.watch(genColorSchemeProvider(Brightness.dark)),
      currentScheme: context.colorScheme,
      floatingBar: ref.watch(_floatingBarProvider),
      tabAnimation: ref.watch(
        appSettingProvider.select((state) => state.tabAnimation),
      ),
      glass: theme.liquidGlass,
      onModeChanged: (value) => ref
          .read(themeSettingProvider.notifier)
          .update((state) => state.copyWith(themeMode: value)),
      onGlassChanged: (value) => ref
          .read(themeSettingProvider.notifier)
          .update((state) => state.copyWith(liquidGlass: value)),
      preview: const ThemeLivePreview(),
      pureBlack: const _PureBlackItem(),
      primaryColor: const _PrimaryColorItem(),
      navigationBar: const _NavigationBarItem(),
      tabAnimationControl: const _TabAnimationItem(),
      platformSettings: const _SidebarBlurItem(),
      fontFamily: const _FontFamilyItem(),
      textScale: const _TextScaleFactorItem(),
    );
  }
}

class _PrimaryColorItem extends ConsumerWidget {
  const _PrimaryColorItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeSettingProvider);
    return AppearancePaletteControl(
      value: AppearancePalette(
        primaryColor: theme.primaryColor,
        primaryColors: theme.primaryColors,
        colorStyle: theme.colorStyle,
      ),
      systemColor: ref
          .watch(dynamicColorProvider)
          .seedOf(Theme.of(context).brightness),
      floatingBar: ref.watch(_floatingBarProvider),
      liquidGlass: ref.watch(_liquidGlassProvider),
      pureBlack: theme.pureBlack,
      onChanged: (value) => ref
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              primaryColor: value.primaryColor,
              primaryColors: value.primaryColors,
              colorStyle: value.colorStyle,
            ),
          ),
    );
  }
}

final _floatingBarProvider = appSettingProvider.select(
  (state) => state.floatingNavigationBar,
);
final _liquidGlassProvider = themeSettingProvider.select(
  (state) => state.liquidGlass != LiquidGlassMode.none,
);

class _PureBlackItem extends ConsumerWidget {
  const _PureBlackItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) => PureBlackChoice(
    value: ref.watch(themeSettingProvider.select((state) => state.pureBlack)),
    standardScheme: ref.watch(
      genColorSchemeProvider(Brightness.dark, pureBlack: false),
    ),
    blackScheme: ref.watch(
      genColorSchemeProvider(Brightness.dark, pureBlack: true),
    ),
    floatingBar: ref.watch(_floatingBarProvider),
    liquidGlass: ref.watch(_liquidGlassProvider),
    onChanged: (value) => ref
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(pureBlack: value)),
  );
}

class _NavigationBarItem extends ConsumerWidget {
  const _NavigationBarItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) => NavigationBarChoice(
    value: ref.watch(_floatingBarProvider),
    liquidGlass: ref.watch(_liquidGlassProvider),
    onChanged: (value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(floatingNavigationBar: value)),
  );
}

class _TabAnimationItem extends ConsumerWidget {
  const _TabAnimationItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) => TabAnimationChoice(
    value: ref.watch(appSettingProvider.select((state) => state.tabAnimation)),
    floatingBar: ref.watch(_floatingBarProvider),
    liquidGlass: ref.watch(_liquidGlassProvider),
    onChanged: (value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(tabAnimation: value)),
  );
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    return TextScaleControl(
      enabled: textScale.enable,
      scale: textScale.scale,
      systemScale: systemTextScaleOf(context),
      onChanged: (enabled, scale) => ref
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith.textScale(enable: enabled, scale: scale),
          ),
    );
  }
}

class _SidebarBlurItem extends ConsumerWidget {
  const _SidebarBlurItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!feature.sidebarBlur || (!system.isMacOS && !system.isWindows)) {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    final sidebarBlur = ref.watch(
      themeSettingProvider.select((state) => state.sidebarBlur),
    );
    return ListItem.toggle(
      leading: const GlyphIcon(AppGlyphs.blur),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.sidebarBlur,
        style: AppTextStyle.subheadline
            .of(context, emphasized: true)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(appLocalizations.sidebarBlurDesc),
      value: sidebarBlur,
      onChanged: (value) {
        ref
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(sidebarBlur: value));
      },
    );
  }
}

class _FontFamilyItem extends ConsumerWidget {
  const _FontFamilyItem();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(
      themeSettingProvider.select((state) => state.fontFamily),
    );
    return AppearanceFontControl(
      fontFamily: family,
      label: family ?? context.appLocalizations.defaultText,
      pageBuilder: (_) => const FontFamilyView(),
    );
  }
}
