import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/account_host.dart';
import 'package:fl_clash/iping/account_insights.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/pages/account_page.dart';
import 'package:fl_clash/iping/profile_widgets.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/topup.dart';
import 'package:fl_clash/iping/topup_form.dart';
import 'package:fl_clash/iping/tunnel_digest.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _payTopup(IpingTopupOrder order) async {
  final url = Uri.tryParse(order.payUrl ?? '');
  if (url == null || !url.isScheme('https') && !url.isScheme('http')) return;
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<bool> _cancelTopup(WidgetRef ref, IpingTopupOrder order) async {
  final l = currentAppLocalizations;
  final confirmed = await dialogs.showMessage(
    title: l.ipingTopupCancel,
    message: TextSpan(text: l.ipingTopupCancelConfirm),
    confirmText: l.ipingTopupCancel,
    destructive: true,
  );
  if (confirmed != true) return false;
  try {
    await ref.read(ipingAuthenticatedApiProvider).cancelTopup(order.id);
    return true;
  } on IpingException {
    dialogs.showNotifier(l.ipingTopupCancelFailed, level: MessageLevel.error);
    return false;
  }
}

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
    if (await showIpingTopup(context) == true) _refresh();
  }

  Future<void> _openHistory() =>
      showInSheet<void>(context, builder: (_) => const IpingTopupHistory());

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final authorized = ref.watch(
      ipingSessionProvider.select((s) => s.account?.apiKey != null),
    );
    final account = ref.watch(ipingSessionProvider.select((s) => s.account));
    final session = ref.watch(ipingBackendStateProvider);
    final info = ref.watch(ipingUserInfoProvider);
    final digest = ref.watch(ipingTunnelDigestProvider).value;
    final referrals = account == null
        ? null
        : ref.watch(ipingReferralStatsProvider(account)).value;
    final user = info.value;
    final shortfall = user == null ? null : digest?.shortfall(user.balance);
    return IpingAccountPage(
      host: _NativeAccountHost(
        profile: user == null
            ? null
            : IpingAccountProfile(
                info: user,
                onTopUp: user.status == 'active' ? _topUp : null,
                onHistory: _openHistory,
              ),
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
        onSignOut: ref.read(ipingClientControllerProvider).signOut,
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

  @override
  IpingAccountSubscription? get subscription => null;
}

class IpingTopupHistory extends ConsumerStatefulWidget {
  const IpingTopupHistory({super.key});

  @override
  ConsumerState<IpingTopupHistory> createState() => _IpingTopupHistoryState();
}

class _IpingTopupHistoryState extends ConsumerState<IpingTopupHistory> {
  static const _perPage = 20;

  late final AppLifecycleListener _lifecycle;
  final _orders = <IpingTopupOrder>[];
  var _total = 0;
  var _loaded = false;
  var _loading = true;
  var _failed = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reload);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _reload() => _start(reset: true);

  void _start({required bool reset}) {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_load(reset: reset));
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    try {
      final page = await ref
          .read(ipingAuthenticatedApiProvider)
          .topupOrders(
            page: reset ? 1 : _orders.length ~/ _perPage + 1,
            perPage: _perPage,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _orders.clear();
        _orders.addAll(page.orders);
        _total = page.total;
        _loaded = true;
      });
    } on IpingException {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancel(IpingTopupOrder order) async {
    if (!await _cancelTopup(ref, order) || !mounted) return;
    _reload();
  }

  bool get _hasMore => _orders.length < _total;

  Widget _buildFooter(BuildContext context) {
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () => _start(reset: false),
          child: Text(context.appLocalizations.retry),
        ),
      );
    }
    if (!_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading && !_failed && _hasMore) {
          _start(reset: false);
        }
      });
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CommonCircleLoading()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final failedFirst = _failed && !_loaded;
    return CommonScaffold(
      title: l.ipingTopupHistory,
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: _loading && !_loaded,
          isEmpty: failedFirst || _loaded && _orders.isEmpty,
          nullStatus: NullStatus(
            illustration: failedFirst
                ? NullStatusIllustration.error
                : NullStatusIllustration.data,
            label: failedFirst ? l.ipingTopupHistoryFailed : l.ipingTopupEmpty,
            action: failedFirst
                ? TextButton(onPressed: _reload, child: Text(l.retry))
                : null,
          ),
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              context.appBarInset,
              16,
              24 + BottomInsetScope.of(context),
            ),
            itemCount: _orders.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _orders.length) return _buildFooter(context);
              final order = _orders[index];
              return ItemPositionProvider(
                position: ItemPosition.get(index, _orders.length),
                child: IpingTopupOrderItem(
                  order: order,
                  onPay: () => _payTopup(order),
                  onCancel: () => _cancel(order),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
