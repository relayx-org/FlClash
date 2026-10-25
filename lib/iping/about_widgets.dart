import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/ui.dart';
import '../ui/icons/icons.dart';
import 'brand.dart';
import 'site_config.dart';

class IpingAboutSummary extends StatelessWidget {
  const IpingAboutSummary({
    super.key,
    required this.site,
    this.version,
    required this.onTerms,
    required this.onPrivacy,
  });
  final IpingSiteConfig site;
  final String? version;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return generateSection(
      title: l.about,
      items: [
        ListItem(
          leading: IpingLogo(src: site.logoUrl),
          title: Text(site.name),
          subtitle: version == null ? null : Text(l.ipingVersion(version!)),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.textShort),
          title: Text(l.ipingTerms),
          onTap: onTerms,
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.lock),
          title: Text(l.ipingPrivacy),
          onTap: onPrivacy,
        ),
      ],
    );
  }
}
