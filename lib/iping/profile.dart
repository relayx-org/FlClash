import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_insights.dart';
import 'api.dart';
import 'backend_native.dart';
import 'profile_widgets.dart';
import 'providers.dart';
import 'topup.dart';
import 'topup_form.dart';
import 'tunnel_digest.dart';

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

class IpingProfile extends ConsumerStatefulWidget {
  const IpingProfile({super.key});

  @override
  ConsumerState<IpingProfile> createState() => _IpingProfileState();
}

class _IpingProfileState extends ConsumerState<IpingProfile> {
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
    ref.invalidate(ipingRecentTopupsProvider);
    ref.invalidate(ipingTunnelDigestProvider);
    ref.invalidate(ipingReferralStatsProvider);
    ref.invalidate(ipingTrafficStatsProvider);
  }

  Future<void> _topUp() async {
    if (await showIpingTopup(context) == true) _refresh();
  }

  Future<void> _cancel(IpingTopupOrder order) async {
    if (await _cancelTopup(ref, order)) _refresh();
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

  List<Widget> _recentItems(AsyncValue<IpingTopupPage?> recent) {
    final l = context.appLocalizations;
    final page = recent.value;
    final orders = page?.orders;
    return [
      ...?orders?.map(
        (order) => IpingTopupOrderItem(
          order: order,
          onPay: () => _payTopup(order),
          onCancel: () => _cancel(order),
        ),
      ),
      if (orders == null && recent.hasError)
        ListItem(title: Text(l.ipingTopupHistoryFailed)),
      if (orders != null && orders.isEmpty)
        ListItem(title: Text(l.ipingTopupEmpty)),
      if (page != null && page.total > page.orders.length)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.clock),
          title: Text(l.ipingTopupHistory),
          trailing: const DisclosureIndicator(),
          onTap: () => showInSheet<void>(
            context,
            builder: (_) => const IpingTopupHistory(),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final authorized = ref.watch(
      ipingSessionProvider.select((s) => s.account?.apiKey != null),
    );
    final account = ref.watch(ipingSessionProvider.select((s) => s.account));
    final info = ref.watch(ipingUserInfoProvider);
    final recent = ref.watch(ipingRecentTopupsProvider);
    final digest = ref.watch(ipingTunnelDigestProvider).value;
    final referrals = account == null
        ? null
        : ref.watch(ipingReferralStatsProvider(account)).value;
    final traffic = account == null
        ? null
        : ref.watch(ipingTrafficStatsProvider(account)).value;
    final user = info.value;
    final shortfall = user == null ? null : digest?.shortfall(user.balance);
    final onTopUp = user?.status == 'active' ? _topUp : null;
    final busy = info.isLoading || recent.isLoading;
    return CommonScaffold(
      title: l.ipingProfileCenter,
      primaryAction: authorized
          ? IconButtonData(
              glyph: AppGlyphs.refresh,
              tooltip: l.ipingRefreshAccount,
              isLoading: busy,
              onPressed: busy ? null : _refresh,
            )
          : null,
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: info.isLoading && user == null,
          isEmpty: user == null,
          nullStatus: _nullStatus(info, authorized),
          child: user == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    context.appBarInset,
                    16,
                    24 + BottomInsetScope.of(context),
                  ),
                  children: [
                    IpingProfileHeader(info: user, onTopUp: onTopUp),
                    if (digest != null && shortfall != null) ...[
                      const SizedBox(height: 12),
                      IpingRenewalWarning(
                        count: digest.renewalCount,
                        cost: digest.renewalCost,
                        shortfall: shortfall,
                        onTopUp: onTopUp,
                      ),
                    ],
                    if (traffic != null) IpingTrafficChart(stats: traffic),
                    generateSection(
                      title: l.ipingRecentTopups,
                      items: _recentItems(recent),
                    ),
                    if (referrals != null)
                      IpingReferralSection(stats: referrals),
                  ],
                ),
        ),
      ),
    );
  }
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
    ref.invalidate(ipingRecentTopupsProvider);
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
