import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/group_monogram.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';
import 'record_frame.dart';

const _blockInset = 10.0;

class DashboardProxyGroupsFrame extends StatelessWidget {
  const DashboardProxyGroupsFrame({
    super.key,
    required this.count,
    required this.itemBuilder,
    required this.empty,
    this.onOpen,
    this.header,
  });
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final Widget empty;
  final Widget? header;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final padding = dashboardCardPadding(density);
    final height = (density.isCompact ? 52 : 60) * scale;
    final gap = density.isCompact ? 6.0 : 8.0;
    final l = AppLocalizations.of(context);
    return DashboardCard(
      semanticLabel: l.proxyGroup,
      padding: padding.copyWith(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header ?? DashboardProxyGroupsHeader(count: count, onOpen: onOpen),
          SizedBox(
            height:
                connectionsTableTop(density, scale) -
                padding.top -
                DashboardCardHeader.height * scale,
          ),
          Expanded(
            child: count == 0
                ? empty
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 344 * scale + gap
                          ? 2
                          : 1;
                      final rows = (count / columns).ceil();
                      final grid = GridView.builder(
                        padding: EdgeInsets.only(bottom: padding.bottom),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: height,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                        ),
                        itemCount: count,
                        itemBuilder: itemBuilder,
                      );
                      return rows * height + (rows - 1) * gap + padding.bottom >
                              constraints.maxHeight
                          ? DashboardFadeOut(child: grid)
                          : grid;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DashboardGroupIcon extends StatelessWidget {
  const DashboardGroupIcon({
    super.key,
    required this.name,
    required this.src,
    this.image,
    required this.size,
    required this.radius,
    this.ring,
  });

  final String name;
  final String src;
  final Widget? image;
  final double size;
  final double radius;
  final Color? ring;

  static const _inset = 0.15;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final ring = this.ring;
    final inset = size * _inset;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(inset),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone2,
        shape: AppShape.all(radius).copyWith(
          side: ring == null
              ? BorderSide.none
              : BorderSide(
                  color: ring,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
        ),
      ),
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            size: size - inset * 2,
            color: colorScheme.onSurfaceVariant,
          ),
          child:
              image ??
              (src.isEmpty
                  ? GroupMonogram(name)
                  : Image.network(
                      src,
                      errorBuilder: (_, _, _) => GroupMonogram(name),
                    )),
        ),
      ),
    );
  }
}

class DashboardProxyGroupTile extends StatelessWidget {
  const DashboardProxyGroupTile({
    super.key,
    required this.name,
    required this.icon,
    required this.selected,
    this.delay,
    required this.onTap,
  });

  final String name;
  final Widget icon;
  final Widget selected;
  final Widget? delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashboardBlock(
      radius: DashboardCorner.block,
      padding: const EdgeInsetsDirectional.fromSTEB(_blockInset, 0, 14, 0),
      onTap: onTap,
      semanticLabel: name,
      child: Row(
        spacing: 12,
        children: [
          icon,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: EmojiText(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    ?delay,
                  ],
                ),
                selected,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardProxyGroupsHeader extends StatelessWidget {
  const DashboardProxyGroupsHeader({
    super.key,
    required this.count,
    this.showCount = true,
    this.leading = const [],
    this.onOpen,
  });
  final int count;
  final bool showCount;
  final List<Widget> leading;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    return DashboardCardHeader(
      glyph: AppGlyphs.layers,
      title: appLocalizations.proxyGroup,
      chevron: mobile && count > 0,
      leading: [
        if (showCount && count > 0)
          Tooltip(
            message: appLocalizations.groupCount(count),
            child: DashboardChip(label: '$count'),
          ),
        ...leading,
      ],
      trailing: [
        if (!mobile)
          Transform.translate(
            offset: const Offset(8, 0),
            child: DashboardIconButton(
              glyph: AppGlyphs.chevronForward,
              tooltip: appLocalizations.proxyGroup,
              onPressed: count == 0 ? null : onOpen,
            ),
          ),
      ],
    );
  }
}
