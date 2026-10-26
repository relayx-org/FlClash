import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'intranet_frame.dart';

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }
}

class IntranetIpCard extends ConsumerWidget {
  const IntranetIpCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DashboardIntranetCard(
    localIp: ref.watch(localIpProvider),
    allowLan: ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    ),
    port: ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    ),
    onCopy: (address) => copyToClipboard(context, address),
    onChanged: (value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(allowLan: value)),
  );
}
