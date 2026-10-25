import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class CustomResourcesSettingsPage extends StatelessWidget {
  const CustomResourcesSettingsPage({
    super.key,
    this.application,
    this.proxies,
    this.providers,
    this.filters,
    this.icons,
    this.groupIcons,
  });
  final Widget? application;
  final Widget? proxies;
  final Widget? providers;
  final Widget? filters;
  final Widget? icons;
  final Widget? groupIcons;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BaseScaffold(
      title: l.customProfileResources,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        children: [
          generateSection(
            items: [
              if (application != null)
                ListItem.open(
                  title: Text(l.applyResources),
                  leading: const GlyphIcon(AppGlyphs.check),
                  widget: application!,
                ),
              if (proxies != null)
                ListItem.open(
                  title: Text(l.proxies),
                  leading: const GlyphIcon(AppGlyphs.proxies),
                  widget: proxies!,
                ),
              if (providers != null)
                ListItem.open(
                  title: Text(l.ruleProviders),
                  leading: const GlyphIcon(AppGlyphs.resources),
                  widget: providers!,
                ),
              if (filters != null)
                ListItem.open(
                  title: Text(l.filters),
                  leading: const GlyphIcon(AppGlyphs.filter),
                  widget: filters!,
                ),
              if (icons != null)
                ListItem.open(
                  title: Text(l.iconSets),
                  leading: const GlyphIcon(AppGlyphs.photos),
                  widget: icons!,
                ),
              if (groupIcons != null)
                ListItem.open(
                  title: Text(l.groupIcons),
                  leading: const GlyphIcon(AppGlyphs.photos),
                  widget: groupIcons!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
