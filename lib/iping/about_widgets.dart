import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    this.updateCheck,
    required this.onTerms,
    required this.onPrivacy,
  });
  final IpingSiteConfig site;
  final String? version;
  final Widget? updateCheck;
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
        ?updateCheck,
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

/// Reads the version the running build actually shipped with: package
/// metadata on the app and the Web build's own `version.json` on the router.
class IpingAboutVersionSummary extends StatefulWidget {
  const IpingAboutVersionSummary({
    super.key,
    required this.site,
    required this.onTerms,
    required this.onPrivacy,
    this.updateCheck,
  });
  final IpingSiteConfig site;
  final Widget? updateCheck;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<IpingAboutVersionSummary> createState() =>
      _IpingAboutVersionSummaryState();
}

class _IpingAboutVersionSummaryState extends State<IpingAboutVersionSummary> {
  late final Future<String?> _version = _readVersion();

  static Future<String?> _readVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        final build = info.buildNumber.trim();
        return build.isEmpty ? version : '$version ($build)';
      }
    } catch (_) {}
    const name = String.fromEnvironment('FLUTTER_BUILD_NAME');
    const number = String.fromEnvironment('FLUTTER_BUILD_NUMBER');
    if (name.isEmpty) return null;
    return number.isEmpty ? name : '$name ($number)';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _version,
    builder: (context, snapshot) => IpingAboutSummary(
      site: widget.site,
      version: snapshot.data,
      updateCheck: widget.updateCheck,
      onTerms: widget.onTerms,
      onPrivacy: widget.onPrivacy,
    ),
  );
}
