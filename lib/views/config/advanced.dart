import 'advanced_page.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:material_ui/material_ui.dart';

import 'rules.dart';

class AdvancedConfigView extends StatelessWidget {
  const AdvancedConfigView({super.key});
  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AdvancedSettingsPage(
      network: BaseScaffold(
        title: appLocalizations.network,
        body: const NetworkListView(),
      ),
      dns: const DnsView(),
      rules: const AddedRulesView(),
      scripts: const ScriptsView(),
    );
  }
}
