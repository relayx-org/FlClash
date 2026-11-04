import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/user_agents.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class UserAgentsView extends ConsumerWidget {
  const UserAgentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAgents = ref.watch(
      appSettingProvider.select((state) => state.userAgents),
    );
    final selected = ref.watch(
      ipingSettingsProvider.select((state) => state.text('global-ua')),
    );
    return UserAgentsPage(
      entries: userAgents,
      selected: selected.isEmpty ? null : selected,
      onChanged: (values) => ref
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(userAgents: values)),
      onSelected: (value) => globalState.safeRun(
        () =>
            ref.read(ipingBackendProvider).updateSettings({'global-ua': value}),
      ),
    );
  }
}
