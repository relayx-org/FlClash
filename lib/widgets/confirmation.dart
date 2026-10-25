import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

Future<bool?> confirmChange(
  BuildContext context, {
  required String message,
  required String confirmText,
  bool destructive = true,
}) => showFloatingDialog<bool>(
  context: context,
  child: CommonDialog(
    title: AppLocalizations.of(context).tip,
    destructive: destructive,
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(AppLocalizations.of(context).cancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(confirmText),
      ),
    ],
    child: SelectableText(message),
  ),
);
