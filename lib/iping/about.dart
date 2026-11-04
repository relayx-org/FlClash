import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'about_widgets.dart';
import 'api.dart';
import 'providers.dart';
import 'update_widgets.dart';

class IpingAboutSection extends ConsumerWidget {
  const IpingAboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(ipingSiteConfigProvider);
    return IpingAboutVersionSummary(
      site: site,
      updateCheck: const IpingCheckUpdateItem(),
      onTerms: () => dialogs.openUrl('$ipingSite/terms-of-service.html'),
      onPrivacy: () => dialogs.openUrl('$ipingSite/privacy-policy.html'),
    );
  }
}
