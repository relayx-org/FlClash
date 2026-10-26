import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'desktop_layout.dart';
import 'layout.dart';

class DashboardPanelLayout extends StatelessWidget {
  const DashboardPanelLayout({
    super.key,
    required this.columns,
    required this.gap,
    required this.outbound,
    required this.upload,
    required this.download,
    required this.mode,
    required this.controls,
    required this.intranet,
    required this.profile,
    required this.services,
    required this.memory,
    required this.summaries,
    required this.tables,
    required this.tablesMinHeight,
  });

  final int columns;
  final double gap;
  final Widget outbound;
  final Widget upload;
  final Widget download;
  final Widget mode;
  final List<(int, Widget)> controls;
  final Widget intranet;
  final Widget profile;
  final Widget services;
  final Widget memory;
  final List<Widget> summaries;
  final Widget tables;
  final double tablesMinHeight;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = math.min(
          (constraints.maxWidth - 40 - gap * (columns - 1)) / columns,
          440 * scale,
        );
        return DashboardDesktopLayout(
          columns: columns,
          gap: gap,
          outbound: outbound,
          upload: upload,
          download: download,
          mode: mode,
          controls: controls,
          middle: [
            (1, intranet),
            (1, profile),
            if (columns == 2 || column >= 290 * scale) ...[
              (1, services),
              (1, memory),
            ] else
              (2, services),
          ],
          summaries: summaries,
          tablesMinHeight: tablesMinHeight,
          tables: tables,
        );
      },
    );
  }
}
