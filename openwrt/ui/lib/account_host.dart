import 'dart:async';

import 'package:fl_clash/iping/account_host.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/client_providers.dart';
import 'package:fl_clash/iping/pages/account_page.dart';
import 'package:fl_clash/iping/topup_form.dart';
import 'package:fl_clash/iping/topup_history.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'client.dart';
import 'controller.dart';
import 'settings_host.dart';

class RouterAccountRoute extends ConsumerWidget {
  const RouterAccountRoute({super.key});

  Future<void> _topUp(
    BuildContext context,
    RouterController router,
    IpingApi api,
  ) async {
    final opened = await showIpingTopup(context, api);
    if (opened == true) await router.refreshAccount();
  }

  void _openHistory(BuildContext context, IpingApi api) {
    unawaited(
      showInSheet<void>(context, builder: (_) => IpingTopupHistory(api: api)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    final api = ref.watch(ipingClientProvider);
    final account = router.account;
    final error = router.error;
    final updated = router.status.updated;
    return IpingAccountPage(
      host: _RouterAccountHost(
        router: router,
        profile: account == null
            ? null
            : IpingAccountProfile(
                info: account,
                onTopUp: account.status == 'active'
                    ? () => _topUp(context, router, api)
                    : null,
                onHistory: () => _openHistory(context, api),
              ),
        subscription: IpingAccountSubscription(
          nodes: router.nodes,
          busy: router.busy,
          updatedText: updated == null
              ? null
              : l.profileUpdatedAt(updated.toLocal().toString()),
          failure: error == null
              ? null
              : Semantics(
                  liveRegion: true,
                  child: Text(
                    routerError(context, error),
                    style: AppTextStyle.body
                        .of(context)
                        .copyWith(color: context.colorScheme.error),
                  ),
                ),
          exportUrl: router.status.subscriptionUrl,
          onSync: router.synchronize,
          manualSubscription: router.status.manualSubscription,
          onImport: () => importRouterSubscription(context),
          onSignIn: router.signedIn ? null : () => router.signIn(),
        ),
      ),
    );
  }
}

class _RouterAccountHost implements IpingAccountHost {
  const _RouterAccountHost({
    required this.router,
    required this.profile,
    required this.subscription,
  });

  final RouterController router;
  @override
  final IpingAccountProfile? profile;
  @override
  final IpingAccountSubscription? subscription;

  @override
  List<Widget> get sections => const [];
  @override
  bool get loading => false;
  @override
  NullStatus? get empty => null;
  @override
  bool get busy => router.busy;
  @override
  bool get hasAccountActions => router.status.hasSubscription;
  @override
  VoidCallback? get onRefresh => null;
  @override
  VoidCallback? get onConsole =>
      () => router.client.open('${router.site}/home');
  @override
  VoidCallback? get onSignOut => router.signOut;
}
