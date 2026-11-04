import 'package:material_ui/material_ui.dart';

import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'account_widgets.dart';
import 'site_config.dart';

class IpingSettingsLink {
  const IpingSettingsLink({
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

class IpingAccountSummaryData {
  const IpingAccountSummaryData({
    required this.label,
    required this.site,
    required this.busy,
    required this.onConsole,
    required this.onSignOut,
  });
  final String label;
  final IpingSiteConfig site;
  final bool busy;
  final VoidCallback onConsole;
  final VoidCallback onSignOut;

  Widget build(BuildContext context) => IpingAccountSummary(
    label: label,
    site: site,
    busy: busy,
    onConsole: onConsole,
    onSignOut: onSignOut,
  );
}

/// Everything the shared settings page needs from its host application.
abstract interface class IpingSettingsHost {
  Key? get storageKey;
  IpingAccountSummaryData? get accountSummary;
  List<IpingSettingsLink> get more;
  Locale? get locale;
  ValueChanged<Locale?> get onLocaleChanged;
  WidgetBuilder get themeBuilder;
  List<IpingSettingsLink> get platformSettings;
  String? get settingsFooter;
  Widget? get about;
  List<IpingSettingsLink> get other;
}
