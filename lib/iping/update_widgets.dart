import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'update_provider.dart';
import 'update_view.dart';

export 'update_view.dart' show IpingUpdateDialog, IpingUpdateDialogs;

final ipingUpdateDialogsProvider = Provider((ref) => IpingUpdateDialogs());

class IpingCheckUpdateItem extends ConsumerWidget {
  const IpingCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IpingUpdateCheckItem(
    updater: ref.watch(ipingUpdaterProvider),
    dialogs: ref.watch(ipingUpdateDialogsProvider),
    showResult: (context, message) => dialogs.showMessage(
      context: context,
      title: context.appLocalizations.checkUpdate,
      message: TextSpan(text: message),
    ),
  );
}
