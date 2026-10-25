import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/features/form/rule_form.dart';
import 'package:fl_clash/features/form/rule_item.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'filters_page.dart';
import 'resource_controller.dart';
import 'resource_page.dart';

class IpingAddedRulesPage extends StatelessWidget {
  const IpingAddedRulesPage({
    super.key,
    required this.store,
    this.actionBuilder,
  });
  final IpingResourceStore<IpingAddedRule> store;
  final List<IconButtonData> Function(
    IpingResourceController<IpingAddedRule, String>,
  )?
  actionBuilder;
  @override
  Widget build(BuildContext context) =>
      IpingResourcePage<IpingAddedRule, String>(
        title: AppLocalizations.of(context).addedRules,
        description: AppLocalizations.of(context).resourceLibraryHint,
        store: store,
        keyOf: (item) => item.id,
        nameOf: (item) => item.value,
        subtitleOf: (item) => item.rule.ruleAction.value,
        actionBuilder: actionBuilder,
        itemBuilder: (context, item, index, editing, selected, toggle, edit) =>
            RuleItem(
              rule: item.rule,
              hasMatch: true,
              isEditing: editing,
              isSelected: selected,
              onSelected: toggle,
              onEdit: (_) => edit(),
            ),
        editor: (context, item, controller) => RuleForm(
          rule: item?.rule ?? const Rule(id: 0),
          isNew: item == null,
          onSave: (value) => controller.put(
            IpingAddedRule(id: item?.id ?? uniqueId, rule: value),
            replacing: item?.id,
          ),
          errorMessage: () => resourceErrorMessage(
            controller.error,
            AppLocalizations.of(context),
            label: AppLocalizations.of(context).rule,
          ),
        ),
      );
}
