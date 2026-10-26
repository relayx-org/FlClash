import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

const dashboardTableGap = 12.0;
const _headerHeight = 32.0;
const _minRows = 3;

double dashboardTableTabHeight(DashboardDensity density) =>
    density.isCompact ? 32 : 36;

double dashboardTableRowHeight(DashboardDensity density) =>
    density.isCompact ? 32 : 34;

/// Keeps the pill tabs concentric with the card's corners.
double dashboardTableTabInset(DashboardDensity density) =>
    dashboardCardRadius(density) - dashboardTableTabHeight(density) / 2;

double connectionsTableTop(DashboardDensity density, double scale) =>
    dashboardTableTabInset(density) +
    dashboardTableTabHeight(density) * scale +
    dashboardTableGap;

/// The grid gives the tables a row once they can show their head and a few
/// connections; shorter, it shows the summary cards.
double connectionsTableMinHeight(DashboardDensity density, double scale) =>
    connectionsTableTop(density, scale) +
    (_headerHeight + dashboardTableRowHeight(density) * _minRows) * scale;

class DashboardRecordCard extends StatelessWidget {
  const DashboardRecordCard({
    super.key,
    required this.header,
    required this.child,
  });
  final Widget header;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final tabInset = dashboardTableTabInset(density);
    final cellStart = dashboardCardPadding(density).left - 8;
    return DashboardCard(
      semanticLabel: AppLocalizations.of(context).liveConnections,
      padding: EdgeInsets.fromLTRB(cellStart, tabInset, cellStart, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: dashboardTableTabHeight(density) * scale,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tabInset - cellStart),
              child: header,
            ),
          ),
          const SizedBox(height: dashboardTableGap),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class DashboardFeedCount extends StatelessWidget {
  const DashboardFeedCount(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      dashboardCount(count),
      maxLines: 1,
      style: AppTextStyle.subheadline
          .of(context, emphasized: true)
          .toTabular
          .copyWith(color: DefaultTextStyle.of(context).style.color),
    );
  }
}

class DashboardFeedSegment extends StatelessWidget {
  const DashboardFeedSegment({
    super.key,
    required this.label,
    required this.count,
    required this.height,
    required this.foreground,
  });

  final String label;
  final Widget count;
  final double height;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: count,
            ),
            Text(
              label,
              maxLines: 1,
              style: AppTextStyle.footnote
                  .of(context, emphasized: true)
                  .copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
