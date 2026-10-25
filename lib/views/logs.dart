export '../features/logs/controller.dart';
import '../features/logs/controller.dart';
import '../iping/backend_native.dart';
import 'logs_page.dart';
import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView>
    with RouteMotionHoldMixin<LogsView> {
  final _listController = LogListController();
  String? _error;
  late final ScrollController _scrollController;
  late final _physics = FollowEndScrollPhysics(
    isFollowing: () => _listController.value.autoScrollToEnd,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = sheetScrollController(
      context,
      initialScrollOffset: double.maxFinite,
    );
    unawaited(_readLogs());
    ref.listenManual(logsProvider.select((state) => state.revision), (_, _) {
      updateLogsThrottler();
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      return ref.read(logsProvider.notifier).exportLogs();
    }, title: appLocalizations.exportLogs);
    if (res != true) return;
    unawaited(
      dialogs.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(text: appLocalizations.exportSuccess),
      ),
    );
  }

  Future<void> _readLogs({bool resume = false}) async {
    try {
      final snapshot = await ref.read(ipingBackendProvider).readLogs();
      if (!mounted) return;
      if (_error != null) setState(() => _error = null);
      updateWhenRouteSettled(() {
        if (resume) {
          _listController.resumeAutoScrollToEnd(snapshot.logs);
        } else {
          _listController.setLogs(snapshot.logs);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      if (!mounted) {
        return;
      }
      updateWhenRouteSettled(() => unawaited(_readLogs()));
    }, duration: renderThrottleDuration);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LogsState>(
    valueListenable: _listController,
    builder: (context, state, _) {
      final logs = state.list;
      return LogsPage(
        controller: _scrollController,
        physics: _physics,
        count: logs.length,
        itemBuilder: (context, index) => LogItem(
          log: logs[index],
          onClick: (value) => context.commonScaffoldState?.addKeyword(value),
        ),
        timestampAt: (index) => logs[index].dateTime,
        searching: state.isSearching,
        following: state.autoScrollToEnd,
        error: _error,
        onSearch: _listController.search,
        onKeywords: _listController.updateKeywords,
        onPause: () => _listController.setAutoScrollToEnd(false),
        onResume: () => unawaited(_readLogs(resume: true)),
        onExport: _handleExport,
      );
    },
  );
}

class LogItem extends StatelessWidget {
  const LogItem({super.key, required this.log, this.onClick});
  final Log log;
  final Function(String)? onClick;
  @override
  Widget build(BuildContext context) => LogRecordItem(
    log: LogRecord(
      dateTime: log.dateTime,
      level: log.logLevel.name,
      payload: log.payload,
    ),
    onClick: onClick,
  );
}
