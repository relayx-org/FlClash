import 'dart:async';

import 'package:fl_clash/iping/account_host.dart';
import 'package:fl_clash/iping/account_insights.dart';
import 'package:fl_clash/iping/account_statistics.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/client_providers.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/pages/account_page.dart';
import 'package:fl_clash/iping/topup_form.dart';
import 'package:fl_clash/iping/topup_history.dart';
import 'package:fl_clash/iping/tunnel_digest.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'client.dart';
import 'controller.dart';
import 'settings_host.dart';

final _tunnelDigestProvider = FutureProvider.autoDispose<IpingTunnelDigest>(
  (ref) => ref.watch(ipingClientProvider).tunnelDigest(),
  retry: (_, _) => null,
);

final _referralStatsProvider = FutureProvider.autoDispose<IpingReferralStats>(
  (ref) => ref.watch(ipingClientProvider).referralStats(),
  retry: (_, _) => null,
);

class RouterAccountRoute extends ConsumerStatefulWidget {
  const RouterAccountRoute({super.key});

  @override
  ConsumerState<RouterAccountRoute> createState() => _RouterAccountRouteState();
}

class _RouterAccountRouteState extends ConsumerState<RouterAccountRoute> {
  late final AppLifecycleListener _lifecycle;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    final router = RouterScope.read(context);
    setState(() => _refreshing = true);
    ref.invalidate(_tunnelDigestProvider);
    ref.invalidate(_referralStatsProvider);
    try {
      await Future.wait([router.refresh(force: true), router.refreshAccount()]);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _topUp(RouterController router, IpingApi api) async {
    final opened = await showIpingTopup(context, api);
    if (opened == true) await _refresh();
  }

  void _openHistory(IpingApi api) {
    unawaited(
      showInSheet<void>(context, builder: (_) => IpingTopupHistory(api: api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    final api = ref.watch(ipingClientProvider);
    final account = router.account;
    final error = router.error;
    final updated = router.status.updated;
    final digest = account == null ? null : ref.watch(_tunnelDigestProvider);
    final referrals = account == null
        ? null
        : ref.watch(_referralStatsProvider);
    final summary = digest?.value;
    final shortfall = account == null
        ? null
        : summary?.shortfall(account.balance);
    return IpingAccountPage(
      host: _RouterAccountHost(
        router: router,
        profile: account == null
            ? null
            : IpingAccountProfile(
                info: account,
                onTopUp: account.status == 'active'
                    ? () => _topUp(router, api)
                    : null,
                onHistory: () => _openHistory(api),
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
        sections: [
          if (account != null) ...[
            if (context.isMobileView)
              generateSection(
                title: l.services,
                items: [
                  ListItem.open(
                    leading: const GlyphIcon(AppGlyphs.locate),
                    title: Text(l.ipingNativeIp),
                    widget: const IpingNativeIpPage(),
                  ),
                  ListItem.open(
                    leading: const GlyphIcon(AppGlyphs.swap),
                    title: Text(l.ipingTunnels),
                    widget: const IpingTunnelsPage(),
                  ),
                ],
              ),
            if (summary != null && shortfall != null)
              IpingRenewalWarning(
                count: summary.renewalCount,
                cost: summary.renewalCost,
                shortfall: shortfall,
                onTopUp: account.status == 'active'
                    ? () => _topUp(router, api)
                    : null,
              ),
            if (referrals?.value case final stats?)
              IpingReferralSection(stats: stats),
          ],
        ],
        loading:
            _refreshing ||
            (digest?.isLoading ?? false) ||
            (referrals?.isLoading ?? false),
        hasAccountActions:
            context.isMobileView && router.status.hasSubscription,
        onRefresh: router.signedIn ? _refresh : null,
      ),
    );
  }
}

class _RouterAccountHost implements IpingAccountHost {
  const _RouterAccountHost({
    required this.router,
    required this.profile,
    required this.subscription,
    required this.sections,
    required this.loading,
    required this.hasAccountActions,
    required this.onRefresh,
  });

  final RouterController router;
  @override
  final IpingAccountProfile? profile;
  @override
  final IpingAccountSubscription? subscription;
  @override
  final List<Widget> sections;
  @override
  final bool loading;
  @override
  final bool hasAccountActions;
  @override
  final VoidCallback? onRefresh;

  @override
  NullStatus? get empty => null;
  @override
  bool get busy => router.busy;
  @override
  VoidCallback? get onConsole =>
      () => router.client.open('${router.site}/home');
  @override
  VoidCallback? get onSignOut => router.signOut;
}
