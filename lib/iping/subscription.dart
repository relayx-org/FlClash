import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'providers.dart';

class IpingSubscriptionDetails extends ConsumerWidget {
  const IpingSubscriptionDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final session = ref.watch(ipingSessionProvider);
    return CommonScaffold(
      title: l.subscriptionInfo,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            context.appBarInset + 24,
            24,
            32 + BottomInsetScope.of(context),
          ),
          children: [
            Text(
              session.nodes > 0
                  ? l.ipingNodeCount(session.nodes)
                  : l.ipingNoNodes,
              style: AppTextStyle.headline.of(context),
            ),
            if (session.updated case final updated?) ...[
              const SizedBox(height: 12),
              Text(
                l.profileUpdatedAt(updated.getLastUpdateTimeDesc(context)),
                style: AppTextStyle.footnote.of(context),
              ),
            ],
            if (session.failure case final failure?) ...[
              const SizedBox(height: 16),
              IpingFailureText(failure: failure),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: session.busy
                  ? null
                  : ref.read(ipingSessionProvider.notifier).synchronize,
              child: Text(session.busy ? l.ipingSyncing : l.ipingSync),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => dialogs.openUrl('$ipingSite/home'),
              child: Text(l.ipingConsole),
            ),
          ],
        ),
      ),
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
