import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/tracker.dart';
import 'package:fl_clash/features/connection/connection.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/record_table.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';
import 'outbound_names.dart';

const _maxFeedRows = 100;
const _midTableWidth = 620.0;
const _wideTableWidth = 880.0;
const _cellInset = 8.0;
const _headerHeight = 32.0;

class DashboardRecordTable<T> extends StatefulWidget {
  const DashboardRecordTable({
    super.key,
    required this.tableId,
    required this.items,
    required this.rowHeight,
    required this.columnsOf,
  });

  final String tableId;
  final List<T> items;
  final double rowHeight;
  final List<RecordColumn<T>> Function(double width) columnsOf;

  @override
  State<DashboardRecordTable<T>> createState() =>
      _DashboardRecordTableState<T>();
}

class _DashboardRecordTableState<T> extends State<DashboardRecordTable<T>>
    with RecordColumnWidthsMixin<DashboardRecordTable<T>> {
  final _sorter = RecordSorter<T>();
  RecordSort? _sort;

  @override
  String get tableId => widget.tableId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final rowHeight = widget.rowHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = widget.columnsOf(constraints.maxWidth);
        final layouts = [for (final column in columns) column.layout];
        final widths = tableColumnWidths(
          layouts,
          constraints.maxWidth,
          columnWidths,
        );
        final sorted = _sorter.sort(widget.items, columns, _sort);
        final items = sorted.length > _maxFeedRows
            ? sorted.sublist(0, _maxFeedRows)
            : sorted;
        final headerStyle = AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(color: colorScheme.onSurfaceVariant);
        final headerHeight =
            _headerHeight * DashboardDensityScope.scaleOf(context);
        final overflows =
            items.length * rowHeight + 2 > constraints.maxHeight - headerHeight;
        final shape = AppShape.all(DashboardCorner.tableHeader);
        final fill = ShapeDecoration(
          color: DashboardColors.of(context).tone,
          shape: shape,
        );
        final body = ListView.builder(
          padding: const EdgeInsets.only(top: 2),
          itemExtent: rowHeight,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final cells = DefaultTextStyle.merge(
              style: AppTextStyle.footnote.of(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: TableCells(
                columns: layouts,
                widths: widths,
                height: rowHeight,
                inset: _cellInset,
                cells: [
                  for (final column in columns) column.cell(context, item),
                ],
              ),
            );
            return index.isOdd
                ? DecoratedBox(decoration: fill, child: cells)
                : cells;
          },
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: fill,
              child: Material(
                type: MaterialType.transparency,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: TableColumnResizer(
                  columns: layouts,
                  widths: widths,
                  onResize: (boundary, delta) =>
                      resizeColumn(layouts, widths, boundary, delta),
                  onResizeEnd: saveColumnWidths,
                  onReset: resetColumnWidths,
                  child: TableCells(
                    columns: layouts,
                    widths: widths,
                    height: headerHeight,
                    inset: 0,
                    cells: [
                      for (final column in columns)
                        RecordHeaderCell(
                          label: column.layout.label,
                          end: column.layout.end,
                          style: headerStyle,
                          inset: _cellInset,
                          descending: _sort?.columnId == column.id
                              ? _sort?.descending
                              : null,
                          onTap: column.sortKey == null
                              ? null
                              : () => setState(
                                  () => _sort = nextRecordSort(_sort, column),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          AppLocalizations.of(context).noData,
                          style: DashboardText.label(context),
                        ),
                      ),
                    )
                  : overflows
                  ? DashboardFadeOut(child: body)
                  : body,
            ),
          ],
        );
      },
    );
  }
}

TextStyle _muted(BuildContext context) =>
    TextStyle(color: context.colorScheme.onSurfaceVariant);

class DashboardMuted extends StatelessWidget {
  const DashboardMuted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _muted(context));
  }
}

class DashboardNumber extends StatelessWidget {
  const DashboardNumber(this.text, {super.key, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: muted ? context.colorScheme.onSurfaceVariant : null,
      ),
    );
  }
}

class DashboardSource extends StatelessWidget {
  const DashboardSource(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.characters.firstOrNull ?? '?';
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: ShapeDecoration(
            color: DashboardColors.of(context).tone2,
            shape: AppShape.all(7),
          ),
          child: Center(
            child: Text(
              letter,
              style: AppTextStyle.caption2
                  .of(context, emphasized: true)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Flexible(
          child: Text(
            name.isEmpty ? '—' : name,
            style: AppTextStyle.footnote.of(context, emphasized: true),
          ),
        ),
      ],
    );
  }
}

class DashboardExit extends StatelessWidget {
  const DashboardExit(this.info, {super.key});

  final TrackerInfo info;

  @override
  Widget build(BuildContext context) {
    final exit = info.chains.firstOrNull ?? '';
    return EmojiText(
      exit.isEmpty ? '—' : exit,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: isBuiltinOutbound(exit) ? _muted(context) : null,
    );
  }
}

String _ruleKey(TrackerInfo info) =>
    '${info.rule} ${info.rulePayload}'.toLowerCase();

String _exitKey(TrackerInfo info) =>
    (info.chains.firstOrNull ?? '').toLowerCase();

List<RecordColumn<TrackerInfo>> dashboardConnectionColumns(
  BuildContext context,
  double width,
) {
  final appLocalizations = AppLocalizations.of(context);
  final mid = width >= _midTableWidth;
  final wide = width >= _wideTableWidth;
  return [
    RecordColumn(
      TableColumn('source', appLocalizations.source, width: wide ? 160 : 140),
      cell: (_, info) => DashboardSource(info.metadata.process),
      sortKey: (info) => info.metadata.process.toLowerCase(),
    ),
    RecordColumn(
      TableColumn('target', appLocalizations.target, flex: wide ? 1.3 : 1),
      cell: (_, info) => TrackerTargetText(info),
      sortKey: (info) => info.title.toLowerCase(),
    ),
    if (mid)
      RecordColumn(
        TableColumn(
          'protocol',
          appLocalizations.protocol,
          width: wide ? 52 : 46,
        ),
        cell: (_, info) => DashboardMuted(info.metadata.network.toUpperCase()),
        sortKey: (info) => info.metadata.network.toLowerCase(),
      ),
    if (wide)
      RecordColumn(
        TableColumn('rule', appLocalizations.rule, flex: 1),
        cell: (_, info) => TrackerRuleText(info),
        sortKey: _ruleKey,
      ),
    RecordColumn(
      TableColumn(
        'exit',
        appLocalizations.outboundExit,
        width: wide ? 120 : 100,
      ),
      cell: (_, info) => DashboardExit(info),
      sortKey: _exitKey,
    ),
    RecordColumn(
      TableColumn(
        'download',
        appLocalizations.download,
        width: wide ? 80 : 70,
        end: true,
      ),
      cell: (_, info) => DashboardNumber(dashboardTraffic(info.download)),
      sortKey: (info) => info.download,
      descendingFirst: true,
    ),
    RecordColumn(
      TableColumn(
        'upload',
        appLocalizations.upload,
        width: wide ? 80 : 70,
        end: true,
      ),
      cell: (_, info) => DashboardNumber(dashboardTraffic(info.upload)),
      sortKey: (info) => info.upload,
      descendingFirst: true,
    ),
    if (mid)
      RecordColumn(
        TableColumn(
          'duration',
          appLocalizations.duration,
          width: wide ? 72 : 64,
          end: true,
        ),
        cell: (_, info) => DashboardNumber(
          trackerDurationText(DateTime.now().difference(info.start)),
          muted: true,
        ),
        sortKey: (info) => -info.start.microsecondsSinceEpoch,
        descendingFirst: true,
      ),
  ];
}
