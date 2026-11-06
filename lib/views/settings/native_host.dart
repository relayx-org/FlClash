import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/about.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/pages/settings_page.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/settings_host.dart';
import 'package:fl_clash/iping/support.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/access.dart';
import 'package:fl_clash/views/config/advanced.dart';
import 'package:fl_clash/views/config/custom_resources.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/developer.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class NativeSettingsRoute extends ConsumerWidget {
  const NativeSettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final more = ref.watch(moreToolsSelectorStateProvider).navigationItems;
    final session = ref.watch(ipingBackendStateProvider);
    final site = ref.watch(ipingSiteConfigProvider);
    return IpingSettingsPage(
      host: _NativeSettingsHost(
        storageKey: ipingSettingsStoreKey,
        accountSummary: context.isMobileView && session.hasSubscription
            ? IpingAccountSummaryData(
                label: session.signedIn
                    ? session.email
                    : l.ipingManualSubscription,
                site: site,
                busy: session.busy,
                onConsole: () => dialogs.openUrl('$ipingSite/home'),
                onContact: () => showIpingSupport(context),
                onSignOut: ref.read(ipingClientControllerProvider).signOut,
              )
            : null,
        more: [
          for (final item in more)
            IpingSettingsLink(
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
            IpingSettingsLink(
              glyph: AppGlyphs.keyboard,
              title: l.hotkeyManagement,
              pageBuilder: (_) => const HotKeyView(),
            ),
          if (system.isAndroid)
            IpingSettingsLink(
              glyph: AppGlyphs.appsList,
              title: l.accessControl,
              pageBuilder: (_) => const AccessView(),
            ),
          IpingSettingsLink(
            glyph: AppGlyphs.wrench,
            title: l.advancedConfig,
            pageBuilder: (_) => const AdvancedConfigView(),
          ),
          IpingSettingsLink(
            glyph: AppGlyphs.customize,
            title: l.customProfileResources,
            pageBuilder: (_) => const CustomResourcesView(),
          ),
          IpingSettingsLink(
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
                IpingSettingsLink(
                  glyph: AppGlyphs.cpu,
                  title: l.developerMode,
                  pageBuilder: (_) => const DeveloperView(),
                ),
              ]
            : const [],
      ),
    );
  }
}

class _NativeSettingsHost implements IpingSettingsHost {
  const _NativeSettingsHost({
    required this.storageKey,
    required this.accountSummary,
    required this.more,
    required this.locale,
    required this.onLocaleChanged,
    required this.themeBuilder,
    required this.platformSettings,
    required this.settingsFooter,
    required this.about,
    required this.other,
  });

  @override
  final Key? storageKey;
  @override
  final IpingAccountSummaryData? accountSummary;
  @override
  final List<IpingSettingsLink> more;
  @override
  final Locale? locale;
  @override
  final ValueChanged<Locale?> onLocaleChanged;
  @override
  final WidgetBuilder themeBuilder;
  @override
  final List<IpingSettingsLink> platformSettings;
  @override
  final String? settingsFooter;
  @override
  final Widget? about;
  @override
  final List<IpingSettingsLink> other;
}
