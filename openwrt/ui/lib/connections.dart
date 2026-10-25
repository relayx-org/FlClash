import 'dart:async';

import 'package:fl_clash/features/connection/connection.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/connection/connections_page.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

class RouterConnections extends StatefulWidget {
  const RouterConnections({super.key});
  @override
  State<RouterConnections> createState() => _RouterConnectionsState();
}

class _RouterConnectionsState extends State<RouterConnections>
    with RouteMotionHoldMixin {
  final _list = TrackerInfoListController();
  final _ranker = TrackerSpeedRanker();
  final _items = <TrackerInfo>[];
  late final ScrollController _scroll = sheetScrollController(context);
  Timer? _timer;
  Timer? _searchTimer;
  bool _loading = false;
  bool _loaded = false;
  bool _reloadPending = false;
  String _query = '';
  int _total = 0;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null) return;
    _list.addListener(_filterChanged);
    _scroll.addListener(_scrollChanged);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          PageActivityScope.isActiveOf(context) &&
          (!_scroll.hasClients || _scroll.position.pixels < 100)) {
        unawaited(_load());
      }
    });
  }

  void _filterChanged() {
    final next = '${_list.value.query} ${_list.value.keywords.join(' ')}'
        .trim();
    if (_query == next) return;
    _query = next;
    _generation++;
    _reloadPending = true;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () => _load());
  }

  void _scrollChanged() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 400 &&
        _items.length < _total &&
        !_loading) {
      unawaited(_load(more: true));
    }
  }

  Future<void> _load({bool more = false}) async {
    final router = RouterScope.of(context);
    if (_loading || !router.connected) return;
    _loading = true;
    _reloadPending = false;
    final generation = _generation;
    try {
      final data = await router.backend.readConnections(
        IpingConnectionQuery(query: _query, offset: more ? _items.length : 0),
      );
      final incoming = data.items;
      if (!mounted || generation != _generation) return;
      updateWhenRouteSettled(() {
        if (!mounted || generation != _generation) return;
        if (!more) _items.clear();
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(incoming.where((item) => ids.add(item.id)));
        _total = data.total;
        _list.setTrackerInfos(_ranker.rank(_items, DateTime.now()));
      });
    } catch (_) {
    } finally {
      _loading = false;
      if (mounted && generation == _generation) setState(() => _loaded = true);
      if (mounted && _reloadPending) unawaited(_load());
    }
  }

  Future<void> _close(String id) async {
    await RouterScope.of(context).closeConnection(id);
    if (mounted) {
      _reloadPending = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => ConnectionsPage(
    controller: _list,
    scrollController: _scroll,
    loaded: _loaded,
    onClose: _close,
    onCloseAll: () => _close(''),
  );

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _searchTimer?.cancel();
    _list.removeListener(_filterChanged);
    _list.dispose();
    _scroll.removeListener(_scrollChanged);
    _scroll.dispose();
    super.dispose();
  }
}
