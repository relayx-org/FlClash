import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/ui/proxy_group_tabs.dart';
import 'package:material_ui/material_ui.dart';

class GroupTabs extends StatelessWidget {
  const GroupTabs({super.key, required this.controller, required this.groups});

  final TabController controller;
  final List<Group> groups;

  @override
  Widget build(BuildContext context) => ProxyGroupTabs(
    controller: controller,
    groups: [for (final group in groups) group.name],
    tooltip: AppLocalizations.of(context).proxyGroup,
  );
}
