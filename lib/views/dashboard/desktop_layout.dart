import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'layout.dart';

const _maxColumnWidth = 440.0;

class DashboardDesktopLayout extends StatelessWidget {
  const DashboardDesktopLayout({
    super.key,
    required this.outbound,
    required this.upload,
    required this.download,
    required this.mode,
    required this.controls,
    required this.middle,
    required this.summaries,
    this.tables,
    required this.tablesMinHeight,
    required this.columns,
    required this.gap,
  });

  final Widget outbound;
  final Widget upload;
  final Widget download;
  final Widget mode;
  final List<(int, Widget)> controls;
  final List<(int, Widget)> middle;
  final List<Widget> summaries;
  final Widget? tables;
  final double tablesMinHeight;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final compact = density.isCompact;
    final scale = DashboardDensityScope.scaleOf(context);
    final base = EdgeInsetsDirectional.fromSTEB(
      16,
      MediaQuery.paddingOf(context).top,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    );
    final topHeight = (compact ? 176 : 208) * scale;
    final controlHeight = (compact ? 56 : 64) * scale;
    final middleHeight = (compact ? 152 : 176) * scale;
    final tablesHeight = tablesMinHeight;
    final summaryHeight = (compact ? 112 : 120) * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room =
            constraints.maxWidth - base.horizontal - gap * (columns - 1);
        final column = math.min(room / columns, _maxColumnWidth * scale);
        final inset = (room - column * columns) / 2;
        final padding = base.copyWith(
          start: base.start + inset,
          end: base.end + inset,
        );
        double span(int columns) => column * columns + gap * (columns - 1);
        Widget row(List<(int, Widget)> cards) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (final (columns, card) in cards)
              SizedBox(
                width: span(columns),
                child: RepaintBoundary(child: card),
              ),
          ],
        );
        Widget sized(double height, Widget child) =>
            SizedBox(height: height, child: child);
        final half = columns ~/ 2;
        final summaryRow = row([
          for (final summary in summaries) (half, summary),
        ]);
        if (columns == 2) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: Column(
              spacing: gap,
              children: [
                sized(topHeight, RepaintBoundary(child: outbound)),
                sized(topHeight, row([(1, upload), (1, download)])),
                sized(controlHeight, RepaintBoundary(child: mode)),
                sized(controlHeight, row(controls)),
                for (var i = 0; i < middle.length; i += 2)
                  sized(middleHeight, row(middle.skip(i).take(2).toList())),
                sized(summaryHeight, summaryRow),
              ],
            ),
          );
        }
        final rows = [
          sized(topHeight, row([(2, outbound), (1, upload), (1, download)])),
          sized(controlHeight, row([(2, mode), ...controls])),
          sized(middleHeight, row(middle)),
        ];
        final rowsHeight =
            padding.vertical +
            topHeight +
            controlHeight +
            middleHeight +
            gap * 3;
        final tablesFit = constraints.maxHeight >= rowsHeight + tablesHeight;
        final fills = constraints.maxHeight >= rowsHeight + summaryHeight;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: fills ? constraints.maxHeight : null,
            child: Padding(
              padding: padding,
              child: Column(
                spacing: gap,
                children: [
                  ...rows,
                  if (tablesFit && tables != null)
                    Expanded(child: tables!)
                  else if (fills)
                    Expanded(child: summaryRow)
                  else
                    sized(summaryHeight, summaryRow),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
