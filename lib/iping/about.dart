import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api.dart';
import 'brand.dart';
import 'providers.dart';

class IpingAboutSection extends ConsumerStatefulWidget {
  const IpingAboutSection({super.key});

  @override
  ConsumerState<IpingAboutSection> createState() => _IpingAboutSectionState();
}

class _IpingAboutSectionState extends ConsumerState<IpingAboutSection> {
  late final _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final site = ref.watch(ipingSiteConfigProvider);
    return generateSection(
      title: l.about,
      items: [
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListItem(
              leading: IpingLogo(src: site.logoUrl),
              title: Text(site.name),
              subtitle: info == null
                  ? null
                  : Text(
                      l.ipingVersion('${info.version} (${info.buildNumber})'),
                    ),
            );
          },
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.textShort),
          title: Text(l.ipingTerms),
          onTap: () => dialogs.openUrl('$ipingSite/terms-of-service.html'),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.lock),
          title: Text(l.ipingPrivacy),
          onTap: () => dialogs.openUrl('$ipingSite/privacy-policy.html'),
        ),
      ],
    );
  }
}
