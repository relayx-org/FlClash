import 'package:material_ui/material_ui.dart';

import '../enum/message_level.dart';
import '../l10n/l10n.dart';

extension AppContextExtension on BuildContext {
  AppLocalizations get appLocalizations => AppLocalizations.of(this);

  void showNotifier(String text, {MessageLevel level = MessageLevel.info}) {
    ScaffoldMessenger.maybeOf(this)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
