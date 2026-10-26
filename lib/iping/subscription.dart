import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'backend_native.dart';
import 'providers.dart';
import 'subscription_page.dart';

class IpingSubscriptionDetails extends ConsumerWidget {
  const IpingSubscriptionDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final session = ref.watch(ipingBackendStateProvider);
    final failure = ref.watch(
      ipingSessionProvider.select((state) => state.failure),
    );
    return IpingSubscriptionPage(
      nodes: session.nodes,
      busy: session.busy,
      updatedText: session.updated == null
          ? null
          : l.profileUpdatedAt(session.updated!.getLastUpdateTimeDesc(context)),
      failure: failure == null ? null : IpingFailureText(failure: failure),
      onSync: () => ref.read(ipingClientControllerProvider).synchronize(),
      onConsole: () => dialogs.openUrl('$ipingSite/home'),
    );
  }
}

class IpingFailureText extends StatelessWidget {
  const IpingFailureText({super.key, required this.failure});
  final IpingFailure failure;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final message = switch (failure) {
      IpingFailure.session => l.ipingSessionExpired,
      IpingFailure.unavailable => l.ipingNetworkError,
      IpingFailure.subscription => l.ipingSubscriptionError,
      IpingFailure.storage => l.ipingStorageError,
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: AppTextStyle.body
            .of(context)
            .copyWith(color: context.colorScheme.error),
      ),
    );
  }
}
