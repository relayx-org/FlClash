import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'backend_native.dart';
import 'providers.dart';
import 'subscription_url.dart';
import 'subscription_page.dart';

Future<void> importIpingSubscription(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(ipingSessionProvider);
  if (session.busy) return;
  final l = context.appLocalizations;
  final url = await dialogs.showCommonDialog<String>(
    context: context,
    child: InputDialog(
      title: session.manualUrl == null
          ? l.ipingImportSubscription
          : l.ipingReplaceSubscription,
      value: session.manualUrl ?? '',
      labelText: l.url,
      validator: (value) =>
          isIpingSubscriptionUrl(value?.trim() ?? '') ? null : l.urlTip(l.url),
    ),
  );
  if (url == null || !context.mounted) return;
  await ref.read(ipingClientControllerProvider).importSubscription(url);
}

Future<void> removeIpingManualSubscription(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(ipingSessionProvider);
  if (session.busy || session.manualUrl == null) return;
  final l = context.appLocalizations;
  final confirmed = await dialogs.showMessage(
    context: context,
    title: l.ipingRemoveManualSubscription,
    message: TextSpan(
      text: session.account != null
          ? l.ipingRemoveManualSubscriptionAccountTip
          : l.ipingRemoveManualSubscriptionTip,
    ),
    confirmText: l.remove,
    destructive: true,
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(ipingClientControllerProvider).removeManualSubscription();
}

class IpingSubscriptionDetails extends ConsumerWidget {
  const IpingSubscriptionDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final session = ref.watch(ipingBackendStateProvider);
    final backend = ref.read(ipingClientControllerProvider);
    final failure = ref.watch(
      ipingSessionProvider.select((state) => state.failure),
    );
    final account = ref.watch(ipingSessionProvider.select((s) => s.account));
    final manualUrl = ref.watch(
      ipingSessionProvider.select((s) => s.manualUrl),
    );
    final exportUrl = manualUrl == null && account != null
        ? ref.read(ipingApiProvider).subscriptionUrl(account.subscriptionToken)
        : null;
    return IpingSubscriptionPage(
      nodes: session.nodes,
      busy: session.busy,
      updatedText: session.updated == null
          ? null
          : l.profileUpdatedAt(session.updated!.getLastUpdateTimeDesc(context)),
      failure: failure == null ? null : IpingFailureText(failure: failure),
      exportUrl: exportUrl,
      manualUrl: manualUrl,
      onSync: backend.synchronize,
      onImport: () => importIpingSubscription(context, ref),
      onRemove: () => removeIpingManualSubscription(context, ref),
      onSignIn: session.signedIn ? null : backend.signIn,
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
