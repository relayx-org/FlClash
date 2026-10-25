import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'resource_controller.dart';
import 'resource_page.dart';
import 'script_form.dart';
import 'script_template.dart';

class IpingScriptsPage extends StatelessWidget {
  const IpingScriptsPage({
    super.key,
    required this.store,
    this.actionBuilder,
    this.menuItemsOf,
    this.addMenuItems = const [],
    this.itemBuilder,
    this.addMenuBuilder,
    this.menuBuilder,
  });
  final IpingResourceStore<IpingScript> store;
  final List<IconButtonData> Function(
    IpingResourceController<IpingScript, String>,
  )?
  actionBuilder;
  final List<CommonPopupMenuItem> Function(IpingScript)? menuItemsOf;
  final List<CommonPopupMenuItem> addMenuItems;
  final IpingResourceItemBuilder<IpingScript>? itemBuilder;
  final List<CommonPopupMenuItem> Function(
    IpingResourceController<IpingScript, String>,
  )?
  addMenuBuilder;
  final List<CommonPopupMenuItem> Function(
    IpingScript,
    IpingResourceController<IpingScript, String>,
  )?
  menuBuilder;
  @override
  Widget build(BuildContext context) => IpingResourcePage<IpingScript, String>(
    title: AppLocalizations.of(context).script,
    description: AppLocalizations.of(context).resourceLibraryHint,
    store: store,
    keyOf: (item) => item.id,
    nameOf: (item) => item.label,
    subtitleOf: (item) => item.url ?? '',
    actionBuilder: actionBuilder,
    menuItemsOf: menuItemsOf,
    addMenuItems: addMenuItems,
    itemBuilder: itemBuilder,
    addMenuBuilder: addMenuBuilder,
    menuBuilder: menuBuilder,
    editor: (context, item, controller) => IpingScriptForm(
      script:
          item ?? IpingScript(id: uniqueId, label: '', content: scriptTemplate),
      reservedLabels: {
        for (final value in controller.items ?? <IpingScript>[])
          if (value.id != item?.id) value.label,
      },
      save: (value) => controller.put(value, replacing: item?.id),
      errorOf: () => controller.error,
    ),
  );
}
