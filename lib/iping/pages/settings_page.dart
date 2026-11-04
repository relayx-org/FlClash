import 'package:material_ui/material_ui.dart';

import '../settings_host.dart';
import 'package:fl_clash/views/settings_page.dart';

class IpingSettingsPage extends StatelessWidget {
  const IpingSettingsPage({super.key, required this.host});

  final IpingSettingsHost host;

  @override
  Widget build(BuildContext context) => SettingsPage(
    storageKey: host.storageKey,
    account: host.accountSummary?.build(context),
    more: host.more,
    locale: host.locale,
    onLocaleChanged: host.onLocaleChanged,
    themeBuilder: host.themeBuilder,
    platformSettings: host.platformSettings,
    settingsFooter: host.settingsFooter,
    about: host.about,
    other: host.other,
  );
}
