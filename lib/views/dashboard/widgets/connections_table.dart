import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/connection/connections.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dns_queries.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'record_table.dart';
import 'record_frame.dart';
export 'record_frame.dart' show connectionsTableTop, connectionsTableMinHeight;

/// Enough to fill the tallest card several times over; the full feed is a
/// tap away.
const _midTableWidth = 620.0;

enum DashboardFeed {
  connections,
  requests,
  dns;

  PageLabel get page => switch (this) {
    connections => PageLabel.connections,
    requests => PageLabel.requests,
    dns => PageLabel.dns,
  };
}

void openDashboardFeed(BuildContext context, DashboardFeed feed) {
  showSnapSheet(
    context,
    initialScrollOffset: feed == DashboardFeed.connections
        ? 0
        : double.maxFinite,
    builder: (_, controller) => NestedPagedSheet(
      builder: (_) => switch (feed) {
        DashboardFeed.connections => ConnectionsView(
          scrollController: controller,
        ),
        DashboardFeed.requests => RequestsView(scrollController: controller),
        DashboardFeed.dns => DnsQueriesView(scrollController: controller),
      },
    ),
  );
}

/// Polls the live connections while the dashboard is shown: the whole list
/// while its table is open, only the count otherwise.
mixin ConnectionsPolling<T extends ConsumerStatefulWidget>
    on
        ConsumerState<T>,
        WidgetsBindingObserver,
        ActivePollingMixin<T>,
        RouteMotionHoldMixin<T> {
  final connectionCount = ValueNotifier(0);
  List<TrackerInfo> connections = const [];
  var tcpCount = 0;
  var udpCount = 0;

  bool get pollsConnections;

  IpingBackend get _backend => ref.read(ipingBackendProvider);

  @override
  Duration get pollInterval => Duration(seconds: pollsConnections ? 1 : 2);

  @override
  void dispose() {
    connectionCount.dispose();
    super.dispose();
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      connectionCount.value = 0;
      if (connections.isNotEmpty && isCurrent()) {
        updateWhenRouteSettled(
          () => setState(() {
            connections = const [];
            tcpCount = 0;
            udpCount = 0;
          }),
        );
      }
      return;
    }
    try {
      if (pollsConnections) {
        final next = (await _backend.readConnections(
          const IpingConnectionQuery(limit: null),
        )).items.toList();
        if (!isCurrent()) return;
        next.sort((a, b) => b.start.compareTo(a.start));
        final tcp = next
            .where((item) => item.metadata.network.toLowerCase() == 'tcp')
            .length;
        connectionCount.value = next.length;
        updateWhenRouteSettled(
          () => setState(() {
            connections = next;
            tcpCount = tcp;
            udpCount = next.length - tcp;
          }),
        );
      } else {
        final count = await _backend.readConnectionCount();
        if (!isCurrent()) return;
        connectionCount.value = count;
      }
    } catch (error) {
      commonPrint.log(
        'dashboard connections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }
}

/// Follows a counter the Core moves per event, at the cadence the feed's own
/// list repaints at.
class ThrottledCount extends ConsumerStatefulWidget {
  const ThrottledCount({
    super.key,
    required this.provider,
    required this.builder,
  });

  final ProviderListenable<int> provider;
  final Widget Function(BuildContext context, int count) builder;

  @override
  ConsumerState<ThrottledCount> createState() => _ThrottledCountState();
}

class _ThrottledCountState extends ConsumerState<ThrottledCount> {
  late var _count = ref.read(widget.provider);
  late var _latest = _count;
  Timer? _repaint;
  var _active = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(widget.provider, (_, next) {
      _latest = next;
      if (!_active) {
        return;
      }
      _repaint ??= Timer(renderThrottleDuration, _showLatest);
    });
  }

  void _showLatest() {
    _repaint = null;
    setState(() => _count = _latest);
  }

  // A card can stay deactivated across timer ticks; a repaint there throws.
  @override
  void deactivate() {
    _active = false;
    _repaint?.cancel();
    _repaint = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _count = _latest;
  }

  @override
  void dispose() {
    _repaint?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _count);
}

class ConnectionsTableCard extends ConsumerStatefulWidget {
  const ConnectionsTableCard({super.key});

  @override
  ConsumerState<ConnectionsTableCard> createState() =>
      _ConnectionsTableCardState();
}

class _ConnectionsTableCardState extends ConsumerState<ConnectionsTableCard>
    with
        WidgetsBindingObserver,
        ActivePollingMixin<ConnectionsTableCard>,
        RouteMotionHoldMixin<ConnectionsTableCard>,
        ConnectionsPolling<ConnectionsTableCard> {
  var _feed = DashboardFeed.connections;
  List<TrackerInfo> _requests = const [];
  List<DnsQuery> _queries = const [];
  Timer? _snapshot;

  @override
  bool get pollsConnections => _feed == DashboardFeed.connections;

  @override
  void initState() {
    super.initState();
    _takeSnapshot();
    ref.listenManual(
      requestsProvider.select((state) => state.revision),
      (_, _) => _scheduleSnapshot(DashboardFeed.requests),
    );
    ref.listenManual(
      dnsQueriesProvider.select((state) => state.revision),
      (_, _) => _scheduleSnapshot(DashboardFeed.dns),
    );
  }

  @override
  void dispose() {
    _snapshot?.cancel();
    super.dispose();
  }

  void _scheduleSnapshot(DashboardFeed feed) {
    if (feed != _feed) return;
    _snapshot ??= Timer(renderThrottleDuration, () {
      _snapshot = null;
      if (mounted) updateWhenRouteSettled(() => setState(_takeSnapshot));
    });
  }

  void _takeSnapshot() {
    switch (_feed) {
      case DashboardFeed.requests:
        _requests = ref.read(requestsProvider).list.reversed.toList();
      case DashboardFeed.dns:
        _queries = ref.read(dnsQueriesProvider).list.reversed.toList();
      case DashboardFeed.connections:
        break;
    }
  }

  void _select(DashboardFeed feed) {
    if (feed == _feed) return;
    setState(() {
      _feed = feed;
      if (feed != DashboardFeed.connections) {
        connections = const [];
      }
      _takeSnapshot();
    });
    if (feed == DashboardFeed.connections) {
      stopPolling();
      startPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final rowHeight = dashboardTableRowHeight(density) * scale;
    final headerHeight = dashboardTableTabHeight(density) * scale;
    Widget segment(DashboardFeed feed, Widget count) =>
        DashboardConnectedButton(
          selected: _feed == feed,
          first: feed == DashboardFeed.values.first,
          last: feed == DashboardFeed.values.last,
          outer: headerHeight / 2,
          inner: 8,
          background: DashboardColors.of(context).tone,
          semanticLabel: feed.page.label,
          onTap: () => _select(feed),
          builder: (foreground) => DashboardFeedSegment(
            label: feed.page.label,
            count: count,
            height: headerHeight,
            foreground: foreground,
          ),
        );
    return DashboardRecordCard(
      header: LayoutBuilder(
        builder: (context, constraints) => DashboardCappedRow(
          share: 0.45,
          start: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: DashboardConnectedGroup(
              children: [
                segment(
                  DashboardFeed.connections,
                  ValueListenableBuilder(
                    valueListenable: connectionCount,
                    builder: (context, count, _) => DashboardFeedCount(count),
                  ),
                ),
                segment(
                  DashboardFeed.requests,
                  ThrottledCount(
                    provider: requestCountProvider,
                    builder: (_, count) => DashboardFeedCount(count),
                  ),
                ),
                segment(
                  DashboardFeed.dns,
                  ThrottledCount(
                    provider: dnsQueryCountProvider,
                    builder: (_, count) => DashboardFeedCount(count),
                  ),
                ),
              ],
            ),
          ),
          end: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (_feed == DashboardFeed.connections &&
                  connections.isNotEmpty &&
                  constraints.maxWidth >= _midTableWidth) ...[
                DashboardChip(
                  label: 'TCP $tcpCount',
                  tone: DashboardChipTone.idle,
                ),
                DashboardChip(
                  label: 'UDP $udpCount',
                  tone: DashboardChipTone.idle,
                ),
              ],
            ],
          ),
        ),
      ),
      child: switch (_feed) {
        DashboardFeed.connections => DashboardRecordTable<TrackerInfo>(
          key: const ValueKey(DashboardFeed.connections),
          tableId: 'dashboard.connections',
          items: connections,
          rowHeight: rowHeight,
          columnsOf: (width) => dashboardConnectionColumns(context, width),
        ),
        DashboardFeed.requests => DashboardRecordTable<TrackerInfo>(
          key: const ValueKey(DashboardFeed.requests),
          tableId: 'dashboard.requests',
          items: _requests,
          rowHeight: rowHeight,
          columnsOf: (_) => _requestColumns(context),
        ),
        DashboardFeed.dns => DashboardRecordTable<DnsQuery>(
          key: const ValueKey(DashboardFeed.dns),
          tableId: 'dashboard.dns',
          items: _queries,
          rowHeight: rowHeight,
          columnsOf: (_) => _dnsColumns(context),
        ),
      },
    );
  }
}

String _timeOf(DateTime time) => time.showTime.trim();

String _ruleKey(TrackerInfo info) =>
    '${info.rule} ${info.rulePayload}'.toLowerCase();

String _exitKey(TrackerInfo info) =>
    (info.chains.firstOrNull ?? '').toLowerCase();

List<RecordColumn<TrackerInfo>> _requestColumns(BuildContext context) {
  final appLocalizations = context.appLocalizations;
  return [
    RecordColumn(
      TableColumn('time', appLocalizations.time, width: 76),
      cell: (_, info) => DashboardNumber(_timeOf(info.start), muted: true),
      sortKey: (info) => info.start,
      descendingFirst: true,
    ),
    RecordColumn(
      TableColumn('source', appLocalizations.source, width: 140),
      cell: (_, info) => DashboardSource(info.metadata.process),
      sortKey: (info) => info.metadata.process.toLowerCase(),
    ),
    RecordColumn(
      TableColumn('target', appLocalizations.target, flex: 1.2),
      cell: (_, info) => TrackerTargetText(info),
      sortKey: (info) => info.title.toLowerCase(),
    ),
    RecordColumn(
      TableColumn('rule', appLocalizations.rule, flex: 1),
      cell: (_, info) => TrackerRuleText(info),
      sortKey: _ruleKey,
    ),
    RecordColumn(
      TableColumn('exit', appLocalizations.outboundExit, width: 100),
      cell: (_, info) => DashboardExit(info),
      sortKey: _exitKey,
    ),
    RecordColumn(
      TableColumn('traffic', appLocalizations.traffic, width: 64, end: true),
      cell: (_, info) =>
          DashboardNumber(dashboardTraffic(info.upload + info.download)),
      sortKey: (info) => info.upload + info.download,
      descendingFirst: true,
    ),
  ];
}

List<RecordColumn<DnsQuery>> _dnsColumns(BuildContext context) {
  final appLocalizations = context.appLocalizations;
  return [
    RecordColumn(
      TableColumn('time', appLocalizations.time, width: 76),
      cell: (_, query) => DashboardNumber(_timeOf(query.time), muted: true),
      sortKey: (query) => query.time,
      descendingFirst: true,
    ),
    RecordColumn(
      TableColumn('domain', appLocalizations.domain, flex: 1.3),
      cell: (context, query) => Text(
        query.domain,
        style: AppTextStyle.footnote.of(context, emphasized: true),
      ),
      sortKey: (query) => query.domain.toLowerCase(),
    ),
    RecordColumn(
      TableColumn('type', appLocalizations.ipType, width: 60),
      cell: (_, query) => DashboardMuted(query.type),
      sortKey: (query) => query.type,
    ),
    RecordColumn(
      TableColumn('initiator', appLocalizations.initiatorShort, width: 52),
      cell: (_, query) => DashboardMuted(query.initiator?.label ?? '—'),
      sortKey: (query) => query.initiator?.label ?? '',
    ),
    RecordColumn(
      TableColumn('result', appLocalizations.result, flex: 1),
      cell: (_, query) => _DnsResult(query),
      sortKey: (query) => query.summary.toLowerCase(),
    ),
    RecordColumn(
      TableColumn('elapsed', appLocalizations.elapsed, width: 72, end: true),
      cell: (_, query) => DashboardNumber('${query.delay} ms', muted: true),
      sortKey: (query) => query.delay,
      descendingFirst: true,
    ),
  ];
}

class _DnsResult extends StatelessWidget {
  const _DnsResult(this.query);

  final DnsQuery query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (query.error.isNotEmpty) {
      return Text(query.error, style: TextStyle(color: colorScheme.error));
    }
    if (query.hasFailureRcode) {
      return Text(
        query.rcode,
        style: AppTextStyle.footnote
            .of(context, emphasized: true)
            .copyWith(color: DashboardColors.of(context).warn),
      );
    }
    final answer = query.answers.firstOrNull ?? '—';
    return Row(
      children: [
        if (query.cached)
          Container(
            height: 18,
            margin: const EdgeInsetsDirectional.only(end: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: ShapeDecoration(
              color: DashboardColors.of(context).tone,
              shape: AppShape.full,
            ),
            child: Center(
              child: Text(
                context.appLocalizations.cache,
                style: AppTextStyle.caption2
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        Flexible(
          child: Text(
            answer,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
