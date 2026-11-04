import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/confirmation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'profile_widgets.dart';
import 'topup.dart';

class IpingTopupHistory extends StatefulWidget {
  const IpingTopupHistory({super.key, required this.api});

  final IpingApi api;

  @override
  State<IpingTopupHistory> createState() => _IpingTopupHistoryState();
}

class _IpingTopupHistoryState extends State<IpingTopupHistory> {
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
      final page = await widget.api.topupOrders(
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

  Future<void> _pay(IpingTopupOrder order) async {
    final url = Uri.tryParse(order.payUrl ?? '');
    if (url == null || !url.isScheme('https') && !url.isScheme('http')) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _cancel(IpingTopupOrder order) async {
    final l = AppLocalizations.of(context);
    final confirmed = await confirmChange(
      context,
      message: l.ipingTopupCancelConfirm,
      confirmText: l.ipingTopupCancel,
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.cancelTopup(order.id);
    } on IpingException {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(l.ipingTopupCancelFailed)));
      }
      return;
    }
    if (mounted) _reload();
  }

  bool get _hasMore => _orders.length < _total;

  Widget _buildFooter(BuildContext context) {
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () => _start(reset: false),
          child: Text(AppLocalizations.of(context).retry),
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
    final l = AppLocalizations.of(context);
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
                  onPay: () => _pay(order),
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
