import 'package:fl_clash/common/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'account_widgets.dart';
import 'api.dart';
import 'backend_native.dart';
import 'providers.dart';

class IpingAccountButton extends ConsumerWidget {
  const IpingAccountButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(ipingBackendStateProvider);
    final backend = ref.read(ipingClientControllerProvider);
    return IpingAccountMenu(
      label: session.signedIn
          ? session.email
          : session.manualSubscription
          ? context.appLocalizations.ipingManualSubscription
          : null,
      site: ref.watch(ipingSiteConfigProvider),
      busy: session.busy,
      onConsole: () => dialogs.openUrl('$ipingSite/home'),
      onSignOut: backend.signOut,
      menuBuilder: (_) => Consumer(
        builder: (_, ref, _) => IpingAccountActions(
          busy: ref.watch(
            ipingBackendStateProvider.select((state) => state.busy),
          ),
          onConsole: () => dialogs.openUrl('$ipingSite/home'),
          onSignOut: backend.signOut,
        ),
      ),
    );
  }
}
