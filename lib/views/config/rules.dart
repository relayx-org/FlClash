import 'package:fl_clash/features/form/rule_preset.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/rules_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddedRulesView extends ConsumerWidget {
  const AddedRulesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IpingAddedRulesPage(
    store: ref.watch(ipingBackendProvider).addedRules,
    actionBuilder: (controller) => [
      IconButtonData(
        glyph: AppGlyphs.rulePresets,
        tooltip: AppLocalizations.of(context).quickActions,
        onPressed: () => showSheet<void>(
          context: context,
          builder: (_) => RulePresetSheet(
            onAdd: (rules) {
              controller.insertAll([
                for (final item in rules)
                  IpingAddedRule(id: item.id.toString(), rule: item),
              ], atStart: true);
            },
          ),
        ),
      ),
    ],
  );
}
