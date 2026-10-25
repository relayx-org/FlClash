import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/account.dart';
import 'package:fl_clash/iping/about.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/advanced.dart';
import 'config/custom_resources.dart';
import 'developer.dart';
import 'theme.dart';
import 'settings_page.dart';

class ToolsView extends ConsumerWidget {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final more = ref.watch(moreToolsSelectorStateProvider).navigationItems;
    return SettingsPage(
      storageKey: toolsStoreKey,
      account: ref.watch(isMobileViewProvider)
          ? const IpingAccountSection()
          : null,
      more: [
        for (final item in more)
          SettingsRouteLink(
            glyph: item.glyph,
            title: item.label.label,
            pageBuilder: item.builder,
            forceFull: item.modes.contains(NavigationItemMode.moreFull),
          ),
      ],
      locale: getLocaleForString(
        ref.watch(appSettingProvider.select((state) => state.locale)),
      ),
      onLocaleChanged: (locale) => ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(locale: locale?.toString())),
      themeBuilder: (_) => const ThemeView(),
      platformSettings: [
        if (system.isDesktop)
          SettingsRouteLink(
            glyph: AppGlyphs.keyboard,
            title: l.hotkeyManagement,
            pageBuilder: (_) => const HotKeyView(),
          ),
        if (system.isAndroid)
          SettingsRouteLink(
            glyph: AppGlyphs.appsList,
            title: l.accessControl,
            pageBuilder: (_) => const AccessView(),
          ),
        SettingsRouteLink(
          glyph: AppGlyphs.wrench,
          title: l.advancedConfig,
          pageBuilder: (_) => const AdvancedConfigView(),
        ),
        SettingsRouteLink(
          glyph: AppGlyphs.customize,
          title: l.customProfileResources,
          pageBuilder: (_) => const CustomResourcesView(),
        ),
        SettingsRouteLink(
          glyph: AppGlyphs.settings,
          title: l.general,
          pageBuilder: (_) => const GeneralView(),
        ),
      ],
      settingsFooter: [
        if (system.isAndroid) l.accessControlDesc,
        l.advancedConfigDesc,
        l.customProfileResourcesDesc,
      ].join('\n'),
      about: const IpingAboutSection(),
      other:
          ref.watch(appSettingProvider.select((state) => state.developerMode))
          ? [
              SettingsRouteLink(
                glyph: AppGlyphs.cpu,
                title: l.developerMode,
                pageBuilder: (_) => const DeveloperView(),
              ),
            ]
          : const [],
    );
  }
}
