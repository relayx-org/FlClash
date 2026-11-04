import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/iping/account_host.dart';
import 'package:fl_clash/iping/account_insights.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/pages/account_page.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/subscription.dart';
import 'package:fl_clash/iping/topup_form.dart';
import 'package:fl_clash/iping/topup_history.dart';
import 'package:fl_clash/iping/tunnel_digest.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class NativeAccountRoute extends ConsumerStatefulWidget {
  const NativeAccountRoute({super.key});

  @override
  ConsumerState<NativeAccountRoute> createState() => _NativeAccountRouteState();
}

class _NativeAccountRouteState extends ConsumerState<NativeAccountRoute> {
  late final AppLifecycleListener _lifecycle;

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

  void _refresh() {
    ref.invalidate(ipingUserInfoProvider);
    ref.invalidate(ipingTunnelDigestProvider);
    ref.invalidate(ipingReferralStatsProvider);
  }

  Future<void> _topUp() async {
    final opened = await showIpingTopup(
      context,
      ref.read(ipingAuthenticatedApiProvider),
      onOpened: () =>
          dialogs.showNotifier(AppLocalizations.of(context).ipingTopupOpened),
    );
    if (opened == true) _refresh();
  }

  Future<void> _openHistory() => showInSheet<void>(
    context,
    builder: (_) =>
        IpingTopupHistory(api: ref.read(ipingAuthenticatedApiProvider)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final authorized = ref.watch(
      ipingSessionProvider.select((s) => s.account?.apiKey != null),
    );
    final account = ref.watch(ipingSessionProvider.select((s) => s.account));
    final failure = ref.watch(
      ipingSessionProvider.select((state) => state.failure),
    );
    final session = ref.watch(ipingBackendStateProvider);
    final backend = ref.read(ipingClientControllerProvider);
    final info = ref.watch(ipingUserInfoProvider);
    final digest = ref.watch(ipingTunnelDigestProvider).value;
    final referrals = account == null
        ? null
        : ref.watch(ipingReferralStatsProvider(account)).value;
    final user = info.value;
    final shortfall = user == null ? null : digest?.shortfall(user.balance);
    final exportUrl = !session.manualSubscription && account != null
        ? ref.read(ipingApiProvider).subscriptionUrl(account.subscriptionToken)
        : null;
    final subscription = user != null || !authorized && session.hasSubscription
        ? IpingAccountSubscription(
            nodes: session.nodes,
            busy: session.busy,
            updatedText: session.updated == null
                ? null
                : l.profileUpdatedAt(
                    session.updated!.getLastUpdateTimeDesc(context),
                  ),
            failure: failure == null
                ? null
                : IpingFailureText(failure: failure),
            exportUrl: exportUrl,
            onSync: backend.synchronize,
            onImport: () => importIpingSubscription(context, ref),
            onSignIn: session.signedIn ? null : backend.signIn,
            manualSubscription: session.manualSubscription,
          )
        : null;
    return IpingAccountPage(
      host: _NativeAccountHost(
        profile: user == null
            ? null
            : IpingAccountProfile(
                info: user,
                onTopUp: user.status == 'active' ? _topUp : null,
                onHistory: _openHistory,
              ),
        subscription: subscription,
        sections: [
          if (user != null) ...[
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
            if (digest != null && shortfall != null)
              IpingRenewalWarning(
                count: digest.renewalCount,
                cost: digest.renewalCost,
                shortfall: shortfall,
                onTopUp: user.status == 'active' ? _topUp : null,
              ),
            if (referrals != null) IpingReferralSection(stats: referrals),
          ],
        ],
        loading: info.isLoading,
        empty: _nullStatus(info, authorized),
        busy: session.busy,
        hasAccountActions: context.isMobileView && session.hasSubscription,
        onRefresh: authorized ? _refresh : null,
        onConsole: () => dialogs.openUrl('$ipingSite/home'),
        onSignOut: backend.signOut,
      ),
    );
  }

  NullStatus _nullStatus(AsyncValue<Object?> info, bool authorized) {
    final l = context.appLocalizations;
    if (!authorized) {
      return NullStatus(
        illustration: NullStatusIllustration.permission,
        label: l.ipingAccountAuthorizeHint,
        action: FilledButton(
          onPressed: () => ref.read(ipingClientControllerProvider).signIn(),
          child: Text(l.ipingAccountAuthorize),
        ),
      );
    }
    final error = info.error;
    return NullStatus(
      illustration: NullStatusIllustration.error,
      label: error is IpingException && error.failure == IpingFailure.session
          ? l.ipingSessionExpired
          : l.ipingAccountLoadFailed,
      action: TextButton(onPressed: _refresh, child: Text(l.retry)),
    );
  }
}

class _NativeAccountHost implements IpingAccountHost {
  const _NativeAccountHost({
    required this.profile,
    required this.subscription,
    required this.sections,
    required this.loading,
    required this.empty,
    required this.busy,
    required this.hasAccountActions,
    required this.onRefresh,
    required this.onConsole,
    required this.onSignOut,
  });

  @override
  final IpingAccountProfile? profile;
  @override
  final IpingAccountSubscription? subscription;
  @override
  final List<Widget> sections;
  @override
  final bool loading;
  @override
  final NullStatus? empty;
  @override
  final bool busy;
  @override
  final bool hasAccountActions;
  @override
  final VoidCallback? onRefresh;
  @override
  final VoidCallback? onConsole;
  @override
  final VoidCallback? onSignOut;
}
