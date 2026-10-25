import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'mode_control.dart';

Future<void> _changeMode(WidgetRef ref, Mode mode) async {
  if (ref.read(ipingModeProvider) == mode) return;
  await globalState.safeRun(() => ref.read(ipingBackendProvider).setMode(mode));
}

class OutboundModeCard extends ConsumerWidget {
  const OutboundModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DashboardModeCard(
    mode: ref.watch(ipingModeProvider),
    onChanged: (value) => _changeMode(ref, value),
  );
}

class OutboundModeBar extends ConsumerWidget {
  const OutboundModeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DashboardModeBar(
    mode: ref.watch(ipingModeProvider),
    onChanged: (value) => _changeMode(ref, value),
  );
}
