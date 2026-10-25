import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    super.key,
    this.network,
    this.dns,
    this.rules,
    this.scripts,
  });
  final Widget? network;
  final Widget? dns;
  final Widget? rules;
  final Widget? scripts;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BaseScaffold(
      title: l.advancedConfig,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        children: [
          generateSection(
            items: [
              if (network != null)
                ListItem.open(
                  title: Text(l.network),
                  leading: const GlyphIcon(AppGlyphs.key),
                  widget: network!,
                ),
              if (dns != null)
                ListItem.open(
                  title: const Text('DNS'),
                  leading: const GlyphIcon(AppGlyphs.dns),
                  widget: dns!,
                ),
              if (rules != null)
                ListItem.open(
                  title: Text(l.addedRules),
                  leading: const GlyphIcon(AppGlyphs.rules),
                  widget: rules!,
                ),
              if (scripts != null)
                ListItem.open(
                  title: Text(l.script),
                  leading: const GlyphIcon(AppGlyphs.code),
                  widget: scripts!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
