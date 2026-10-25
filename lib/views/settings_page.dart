import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../enum/appearance.dart';
import '../widgets/appearance_options.dart';
import '../ui/appearance_preview.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

class SettingsRouteLink {
  const SettingsRouteLink({
    required this.glyph,
    required this.title,
    this.pageBuilder,
    this.onTap,
    this.forceFull = true,
  });
  final Glyph glyph;
  final String title;
  final WidgetBuilder? pageBuilder;
  final VoidCallback? onTap;
  final bool forceFull;

  Widget build(BuildContext context) {
    final builder = pageBuilder;
    return builder == null
        ? ListItem(
            leading: GlyphIcon(glyph),
            title: Text(title),
            onTap: onTap,
            trailing: const GlyphIcon(AppGlyphs.openExternal, size: 18),
          )
        : ListItem.open(
            leading: GlyphIcon(glyph),
            title: Text(title),
            widget: builder(context),
            forceFull: forceFull,
          );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.storageKey,
    this.account,
    this.more = const [],
    required this.locale,
    required this.onLocaleChanged,
    required this.themeBuilder,
    this.platformSettings = const [],
    this.settingsFooter,
    this.about,
    this.other = const [],
  });
  final Key? storageKey;
  final Widget? account;
  final List<SettingsRouteLink> more;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final WidgetBuilder themeBuilder;
  final List<SettingsRouteLink> platformSettings;
  final String? settingsFooter;
  final Widget? about;
  final List<SettingsRouteLink> other;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = <Widget>[
      ?account,
      if (more.isNotEmpty)
        generateSection(
          title: l.more,
          items: more.map((link) => link.build(context)),
        ),
      generateSection(
        title: l.settings,
        items: [
          SettingsLocaleItem(value: locale, onChanged: onLocaleChanged),
          SettingsRouteLink(
            glyph: AppGlyphs.paintbrush,
            title: l.theme,
            pageBuilder: themeBuilder,
          ).build(context),
          for (final link in platformSettings) link.build(context),
        ],
        footer: settingsFooter,
      ),
      ?about,
      if (other.isNotEmpty)
        generateSection(
          title: l.other,
          items: other.map((link) => link.build(context)),
        ),
    ];
    return CommonScaffold(
      title: l.settings,
      body: Builder(
        builder: (context) => ListView.builder(
          key: storageKey,
          itemCount: sections.length,
          itemBuilder: (_, index) => sections[index],
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: context.appBarInset,
            bottom: 20 + BottomInsetScope.of(context),
          ),
        ),
      ),
    );
  }
}

class SettingsLocaleItem extends StatelessWidget {
  const SettingsLocaleItem({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final Locale? value;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String label(Locale? locale) => switch (locale?.toString()) {
      null => l.defaultText,
      'en' => l.en,
      'es' => l.es,
      'fr' => l.fr,
      'ja' => l.ja,
      'ko' => l.ko,
      'ru' => l.ru,
      'zh_CN' => l.zhCN,
      final code => code,
    };
    return ListItem<Locale?>.options(
      leading: const GlyphIcon(AppGlyphs.language),
      title: Text(l.language),
      options: [null, ...AppLocalizations.delegate.supportedLocales],
      onChanged: onChanged,
      textBuilder: label,
      value: value,
    );
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BaseScaffold(
    title: AppLocalizations.of(context).theme,
    body: ListView(
      padding: EdgeInsets.only(top: context.appBarInset, bottom: 32),
      children: children,
    ),
  );
}

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({
    super.key,
    required this.mode,
    required this.lightScheme,
    required this.darkScheme,
    required this.currentScheme,
    required this.floatingBar,
    required this.tabAnimation,
    required this.glass,
    required this.onModeChanged,
    required this.onGlassChanged,
    this.preview,
    this.pureBlack,
    this.primaryColor,
    this.navigationBar,
    this.tabAnimationControl,
    this.platformSettings,
    this.fontFamily,
    this.textScale,
  });

  final ThemeMode mode;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final ColorScheme currentScheme;
  final bool floatingBar;
  final TabAnimation tabAnimation;
  final LiquidGlassMode glass;
  final ValueChanged<ThemeMode> onModeChanged;
  final ValueChanged<LiquidGlassMode> onGlassChanged;
  final Widget? preview;
  final Widget? pureBlack;
  final Widget? primaryColor;
  final Widget? navigationBar;
  final Widget? tabAnimationControl;
  final Widget? platformSettings;
  final Widget? fontFamily;
  final Widget? textScale;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      ThemeModeChoice(
        value: mode,
        lightScheme: lightScheme,
        darkScheme: darkScheme,
        floatingBar: floatingBar,
        liquidGlass: glass != LiquidGlassMode.none,
        onChanged: onModeChanged,
      ),
      ?pureBlack,
      ?primaryColor,
      ?navigationBar,
      ?tabAnimationControl,
      LiquidGlassChoice(value: glass, onChanged: onGlassChanged),
    ];
    return AppearancePage(
      children: [
        preview ??
            AppearancePreview(
              colorScheme: currentScheme,
              floatingBar: floatingBar,
              tabAnimation: tabAnimation,
              liquidGlass: glass != LiquidGlassMode.none,
            ),
        for (final control in controls) ...[
          const SizedBox(height: 16),
          control,
        ],
        if (platformSettings != null) ...[
          const SizedBox(height: 16),
          platformSettings!,
        ],
        ?fontFamily,
        if (textScale != null) ...[const SizedBox(height: 16), textScale!],
      ],
    );
  }
}
