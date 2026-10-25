import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api.dart';
import 'about_widgets.dart';
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
    final site = ref.watch(ipingSiteConfigProvider);
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) => IpingAboutSummary(
        site: site,
        version: snapshot.data == null
            ? null
            : '${snapshot.data!.version} (${snapshot.data!.buildNumber})',
        onTerms: () => dialogs.openUrl('$ipingSite/terms-of-service.html'),
        onPrivacy: () => dialogs.openUrl('$ipingSite/privacy-policy.html'),
      ),
    );
  }
}
