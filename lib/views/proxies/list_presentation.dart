import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/ui.dart';
import '../../ui/icons/icons.dart';
import '../../ui/proxy_style.dart';

const proxyGridSpacing = 8.0;

double listHeaderHeightOf(BuildContext context) =>
    24 +
    MeasureScope.of(context).textHeight(AppTextStyle.callout) +
    MeasureScope.of(context).textHeight(AppTextStyle.caption1);

int proxyColumns(double width, ProxiesLayout layout) {
  final columns = max((width / 250).ceil(), 2);
  return switch (layout) {
    ProxiesLayout.tight => columns + 1,
    ProxiesLayout.standard => columns,
    ProxiesLayout.loose => columns - 1,
  };
}

void animateProxyScrollTo(ScrollController controller, double offset) {
  if (!controller.hasClients) return;
  final position = controller.position;
  controller.animateTo(
    offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}

class ProxyGroupPresentation {
  const ProxyGroupPresentation({
    required this.name,
    required this.type,
    required this.count,
    required this.identity,
    required this.expanded,
    required this.selectedName,
    required this.testing,
    required this.itemBuilder,
    required this.iconBuilder,
    required this.selectedIndex,
    required this.onToggle,
    required this.onTest,
  });
  final String name;
  final String type;
  final int count;
  final Object identity;
  final bool expanded;
  final String selectedName;
  final bool testing;
  final IndexedWidgetBuilder itemBuilder;
  final WidgetBuilder iconBuilder;
  final int? Function() selectedIndex;
  final VoidCallback onToggle;
  final VoidCallback onTest;
}

const _pinnedHeaderGap = 8.0;
const _headerInset = 10.0;
const _headerButtonInset = 4.0;
const _groupInset = 16.0;
const _liftDistance = 16.0;
const _groupMinWidth = 360.0;
const _groupMaxColumns = 3;
const _lastRowGrowth = _headerInset - proxyGridSpacing;

class ProxyGroupsList extends StatefulWidget {
  const ProxyGroupsList({
    super.key,
    required this.groups,
    required this.itemHeight,
    required this.layout,
    required this.iconStyle,
    required this.searching,
    required this.gap,
  });
  final List<ProxyGroupPresentation> groups;
  final double itemHeight;
  final ProxiesLayout layout;
  final ProxiesIconStyle iconStyle;
  final bool searching;
  final double gap;

  @override
  State<ProxyGroupsList> createState() => _ProxyGroupsListState();
}

class _ProxyGroupsListState extends State<ProxyGroupsList> {
  late final ScrollController _controller;
  int _columns = 1;
  int _groupColumns = 1;
  double _gap = 0;

  @override
  void initState() {
    super.initState();
    _controller = sheetScrollController(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(String groupName) {
    _autoScrollToGroup(groupName);
    widget.groups.firstWhere((group) => group.name == groupName).onToggle();
  }

  Map<String, double> _getGroupOffsets() {
    final offsets = <String, double>{};
    final rowExtent = widget.itemHeight + proxyGridSpacing;
    final columnOffsets = List.filled(_groupColumns, 0.0);
    for (final (index, group) in widget.groups.indexed) {
      final column = index % _groupColumns;
      offsets[group.name] = columnOffsets[column];
      columnOffsets[column] += listHeaderHeightOf(context) + _gap;
      if (group.expanded) {
        final rowCount = (group.count + _columns - 1) ~/ _columns;
        columnOffsets[column] += _rowsExtent(rowCount, rowExtent);
      }
    }
    return offsets;
  }

  double _getGroupOffset(String groupName) {
    if (!_controller.hasClients || _controller.position.maxScrollExtent == 0) {
      return 0;
    }
    return _getGroupOffsets()[groupName] ?? 0;
  }

  void _scrollToMakeVisibleWithPadding({
    required double containerHeight,
    required double pixels,
    required double start,
    required double end,
    double padding = 24,
  }) {
    final visibleStart = pixels;
    final visibleEnd = pixels + containerHeight;

    final isElementVisible = start >= visibleStart && end <= visibleEnd;
    if (isElementVisible) {
      return;
    }

    double targetScrollOffset;

    if (end <= visibleStart) {
      targetScrollOffset = start;
    } else if (start >= visibleEnd) {
      targetScrollOffset = end - containerHeight + padding;
    } else {
      final visibleTopPart = end - visibleStart;
      final visibleBottomPart = visibleEnd - start;
      if (visibleTopPart.abs() >= visibleBottomPart.abs()) {
        targetScrollOffset = end - containerHeight + padding;
      } else {
        targetScrollOffset = start;
      }
    }

    targetScrollOffset = targetScrollOffset.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    _controller.jumpTo(targetScrollOffset);
  }

  void _autoScrollToGroup(String groupName) {
    final pixels = _controller.position.pixels;
    final offset = _getGroupOffset(groupName);
    _scrollToMakeVisibleWithPadding(
      containerHeight: max(
        _controller.position.viewportDimension -
            context.appBarInset -
            _pinnedHeaderGap,
        0,
      ),
      pixels: pixels,
      start: offset,
      end: offset + listHeaderHeightOf(context),
    );
  }

  void _scrollToGroupSelected(String groupName) {
    final group = widget.groups
        .where((group) => group.name == groupName)
        .firstOrNull;
    final selected = group?.selectedIndex();
    if (selected == null) return;
    final rowOffset =
        (selected ~/ _columns) * (widget.itemHeight + proxyGridSpacing);
    animateProxyScrollTo(_controller, _getGroupOffset(groupName) + rowOffset);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final groups = widget.groups;
    final cardType = widget.itemHeight;
    final proxiesLayout = widget.layout;
    final isSearching = widget.searching;
    return NullStatusSwitcher(
      isEmpty: groups.isEmpty,
      isSearching: isSearching,
      nullStatus: NullStatus(
        illustration: NullStatusIllustration.proxies,
        label: appLocalizations.nullTip(appLocalizations.proxies),
      ),
      child: WidthBuilder(
        builder: (_, maxWidth) {
          final gap = widget.gap;
          final width = max(maxWidth - _groupInset * 2, 0.0);
          final groupColumns = context.isMobileView
              ? 1
              : ((width + gap) / (_groupMinWidth + gap))
                    .floor()
                    .clamp(1, min(_groupMaxColumns, max(groups.length, 1)))
                    .toInt();
          final groupWidth = (width - gap * (groupColumns - 1)) / groupColumns;
          final columns = proxyColumns(
            max(groupWidth - _headerInset * 2, 0),
            proxiesLayout,
          );
          _columns = columns;
          _groupColumns = groupColumns;
          _gap = gap;
          Widget buildGroup(ProxyGroupPresentation group) => _GroupSliver(
            key: _GroupSliverKey(group.name),
            group: group,
            columns: columns,
            itemHeight: cardType,
            iconStyle: widget.iconStyle,
            gap: gap,
            onChange: _handleChange,
            onScrollToSelected: _scrollToGroupSelected,
          );
          final barInset = context.appBarInset;
          return CommonScrollBar(
            controller: _controller,
            thumbVisibility: true,
            child: CustomScrollView(
              key: const PageStorageKey('proxy-groups-list'),
              controller: _controller,
              slivers: [
                PinnedHeaderSliver(
                  child: SizedBox(height: barInset + _pinnedHeaderGap),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: _groupInset),
                  sliver: groupColumns == 1
                      ? SliverMainAxisGroup(
                          slivers: groups.map(buildGroup).toList(),
                        )
                      : SliverCrossAxisGroup(
                          slivers: [
                            for (
                              var column = 0;
                              column < groupColumns;
                              column++
                            ) ...[
                              if (column > 0)
                                SliverConstrainedCrossAxis(
                                  maxExtent: gap,
                                  sliver: const SliverToBoxAdapter(),
                                ),
                              SliverCrossAxisExpanded(
                                flex: 1,
                                sliver: SliverMainAxisGroup(
                                  slivers: [
                                    for (
                                      var index = column;
                                      index < groups.length;
                                      index += groupColumns
                                    )
                                      buildGroup(groups[index]),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 16 + BottomInsetScope.of(context)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

double _rowsExtent(int rowCount, double rowExtent) =>
    rowCount == 0 ? 0 : rowCount * rowExtent + _lastRowGrowth;

class _GroupSliverKey extends ValueKey<String> {
  const _GroupSliverKey(super.value);
}

/// Watches only its own group's fold state, so folding one group leaves the
/// cards of every other group untouched, and keeps its rows sliver while the
/// inputs that shape it are equal.
class _GroupSliver extends StatefulWidget {
  const _GroupSliver({
    super.key,
    required this.group,
    required this.columns,
    required this.itemHeight,
    required this.iconStyle,
    required this.gap,
    required this.onChange,
    required this.onScrollToSelected,
  });

  final ProxyGroupPresentation group;
  final int columns;
  final double itemHeight;
  final ProxiesIconStyle iconStyle;
  final double gap;
  final void Function(String groupName) onChange;
  final void Function(String groupName) onScrollToSelected;

  @override
  State<_GroupSliver> createState() => _GroupSliverState();
}

class _GroupSliverState extends State<_GroupSliver>
    with SingleTickerProviderStateMixin {
  Widget? _rows;
  double _rowExtent = 0;
  late final _controller = AnimationController(
    vsync: this,
    value: widget.group.expanded ? 1 : 0,
  );
  late final _unfold = UnfoldEntryTransition.curveOf(_controller);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((_) => setState(() {}));
  }

  @override
  void dispose() {
    _unfold.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleUnfold(bool isExpand) {
    _controller.duration = context.motionDuration(
      UnfoldEntryTransition.duration,
    );
    isExpand ? _controller.forward() : _controller.reverse();
  }

  @override
  void didUpdateWidget(_GroupSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group.expanded != oldWidget.group.expanded) {
      _handleUnfold(widget.group.expanded);
    }
    if (widget.group.identity != oldWidget.group.identity ||
        widget.group.count != oldWidget.group.count ||
        widget.columns != oldWidget.columns ||
        widget.itemHeight != oldWidget.itemHeight) {
      _rows = null;
    }
  }

  Widget _buildRow(BuildContext context, int row) {
    final children = <Widget>[
      for (var column = 0; column < widget.columns; column++) ...[
        if (column > 0) const SizedBox(width: 8),
        Flexible(
          child: row * widget.columns + column < widget.group.count
              ? SizedBox(
                  height: widget.itemHeight,
                  child: widget.group.itemBuilder(
                    context,
                    row * widget.columns + column,
                  ),
                )
              : const SizedBox(),
        ),
      ],
    ];
    return SurfaceScope(
      level: context.raisedSurfaceLevel,
      child: Padding(
        padding: const EdgeInsets.only(
          left: _headerInset,
          right: _headerInset,
          bottom: proxyGridSpacing,
        ),
        child: Row(children: children),
      ),
    );
  }

  Widget _buildRows(double extent) {
    final countRows =
        (widget.group.count + widget.columns - 1) ~/ widget.columns;
    return SliverFixedExtentList(
      itemExtent: extent,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildRow(context, index),
        childCount: countRows,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  /// The card reaches up behind the header's rounded bottom corners, so the
  /// two read as one while the rows unfold or fold.
  Widget _buildUnfoldingRows(double extent, ShapeDecoration decoration) {
    final countRows =
        (widget.group.count + widget.columns - 1) ~/ widget.columns;
    final visible = min(
      countRows.toDouble(),
      MediaQuery.sizeOf(context).height / extent,
    );
    final count = min(countRows, visible.floor() + 1);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -AppCorner.xl.ap(context),
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(decoration: decoration),
        ),
        SizeTransition(
          sizeFactor: _unfold,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              for (var index = 0; index < count; index++)
                UnfoldEntryTransition(
                  animation: _unfold,
                  index: index,
                  visibleCount: visible,
                  child: SizedBox(
                    height: extent,
                    child: _buildRow(context, index),
                  ),
                ),
              if (count == countRows) const SizedBox(height: _lastRowGrowth),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group.name;
    final isExpand = widget.group.expanded;
    final unfolded = _controller.isCompleted;
    Widget? rows;
    if (!_controller.isDismissed && widget.group.count > 0) {
      final extent = (widget.itemHeight + proxyGridSpacing);
      final decoration = ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
        shape: AppShape.vertical(
          top: AppCorner.none,
          bottom: AppCorner.xl.ap(context),
        ),
      );
      if (!unfolded) {
        _rows = null;
        rows = SliverToBoxAdapter(
          child: _buildUnfoldingRows(extent, decoration),
        );
      } else {
        if (_rows == null || _rowExtent != extent) {
          _rows = _buildRows(extent);
          _rowExtent = extent;
        }
        rows = DecoratedSliver(
          decoration: decoration,
          sliver: SliverMainAxisGroup(
            slivers: [
              _rows!,
              const SliverToBoxAdapter(child: SizedBox(height: _lastRowGrowth)),
            ],
          ),
        );
      }
    } else {
      _rows = null;
    }
    Widget buildHeader({double floating = 0, double lift = 0}) => SizedBox(
      height: listHeaderHeightOf(context),
      child: ProxyGroupHeader(
        iconStyle: widget.iconStyle,
        enterAnimated: false,
        floating: floating,
        lift: lift,
        onScrollToSelected: widget.onScrollToSelected,
        key: ValueKey(groupName),
        isExpand: isExpand,
        unfolded: unfolded,
        group: widget.group,
        onChange: widget.onChange,
      ),
    );
    return SliverPadding(
      padding: EdgeInsets.only(bottom: widget.gap),
      sliver: SliverMainAxisGroup(
        slivers: [_buildPinnedHeader(isExpand, buildHeader), ?rows],
      ),
    );
  }

  /// Rounds the header and lifts it as its own rows scroll under it, and lets
  /// the shadow go before the end of the group pushes it out. The page color
  /// behind its upper half hides the rows that went under it, which would
  /// otherwise show around its top corners and above it. Every header is laid
  /// out on every pass, so one beyond the cache area builds nothing.
  Widget _buildPinnedHeader(
    bool isExpand,
    Widget Function({double floating, double lift}) buildHeader,
  ) {
    final columns = widget.columns;
    final rowCount = (widget.group.count + columns - 1) ~/ columns;
    final rowsExtent = isExpand ? _rowsExtent(rowCount, _rowExtent) : 0.0;
    final groupExtent =
        listHeaderHeightOf(context) +
        (_controller.isDismissed
            ? 0.0
            : _rowsExtent(rowCount, (widget.itemHeight + proxyGridSpacing)));
    (double, double, double, Color)? headerState;
    Widget? header;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final beyondCache =
            constraints.remainingCacheExtent <= 0 ||
            constraints.scrollOffset + constraints.cacheOrigin >= groupExtent;
        final under = isExpand
            ? constraints.scrollOffset + constraints.overlap
            : 0.0;
        final state = beyondCache
            ? null
            : (
                (under / _liftDistance).clamp(0.0, 1.0),
                (min(under, rowsExtent - under) / _liftDistance).clamp(
                  0.0,
                  1.0,
                ),
                isExpand ? constraints.overlap : 0.0,
                context.surfaceLevel.colorOf(context.colorScheme),
              );
        if (header != null && state == headerState) {
          return header!;
        }
        headerState = state;
        if (state == null) {
          return header = PinnedHeaderSliver(
            child: SizedBox(height: listHeaderHeightOf(context)),
          );
        }
        final (floating, lift, cover, pageColor) = state;
        return header = PinnedHeaderSliver(
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -cover,
                  left: 0,
                  right: 0,
                  height: cover + listHeaderHeightOf(context) / 2,
                  child: ColoredBox(color: pageColor),
                ),
                buildHeader(floating: floating, lift: lift),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProxyGroupHeader extends StatelessWidget {
  final ProxyGroupPresentation group;
  final ProxiesIconStyle iconStyle;

  final Function(String groupName) onChange;
  final Function(String groupName) onScrollToSelected;
  final bool isExpand;

  /// Whether the rows have settled under the header, squaring its bottom.
  final bool unfolded;

  final bool enterAnimated;

  /// How far the group's own rows have scrolled under the pinned header, as a
  /// fraction of the distance that rounds its bottom corners.
  final double floating;

  /// The shadow that lifts the header off the rows under it.
  final double lift;

  const ProxyGroupHeader({
    required this.iconStyle,
    super.key,
    this.enterAnimated = true,
    this.floating = 0,
    this.lift = 0,
    required this.group,
    required this.onChange,
    required this.onScrollToSelected,
    required this.isExpand,
    required this.unfolded,
  });

  @override
  Widget build(BuildContext context) {
    final groupName = group.name;
    final isDelayTesting = group.testing;
    final colorScheme = context.colorScheme;
    final level = floating > 0
        ? SurfaceLevel.floatingOf(colorScheme)
        : context.raisedSurfaceLevel;
    final radius = AppCorner.xl.ap(context);
    final card = CommonCard(
      enterActionsOnRight: true,
      enterAnimated: enterAnimated,
      key: key,
      radius: radius - _headerButtonInset,
      child: Padding(
        padding: const EdgeInsets.all(_headerInset - _headerButtonInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  _GroupIcon(
                    icon: group.iconBuilder(context),
                    iconStyle: iconStyle,
                  ),
                  Flexible(
                    child: _GroupSummary(
                      groupName: groupName,
                      selectedName: group.selectedName,
                    ),
                  ),
                ],
              ),
            ),
            _GroupActions(
              isExpand: isExpand,
              isDelayTesting: isDelayTesting,
              groupType: group.type,
              onScrollToSelected: () {
                onScrollToSelected(groupName);
              },
              onDelayTest: group.onTest,
              onToggle: () {
                onChange(groupName);
              },
            ),
          ],
        ),
      ),
      onPressed: () {
        onChange(groupName);
      },
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: AppShape.vertical(
          top: radius,
          bottom: unfolded ? radius * floating : radius,
        ),
        shadows: lift == 0 ? null : _floatingShadows(colorScheme, lift),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_headerButtonInset),
        child: SurfaceScope(
          // CommonCard fills one level above its scope.
          level: SurfaceLevel.values[level.index - 1],
          child: card,
        ),
      ),
    );
  }
}

List<BoxShadow> _floatingShadows(ColorScheme colorScheme, double lift) {
  final strength = colorScheme.brightness == Brightness.dark ? 3.0 : 1.0;
  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.08 * strength * lift),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.04 * strength * lift),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.icon, required this.iconStyle});
  final Widget icon;
  final ProxiesIconStyle iconStyle;

  @override
  Widget build(BuildContext context) {
    return switch (iconStyle) {
      ProxiesIconStyle.filled => LayoutBuilder(
        builder: (_, constraints) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                alignment: Alignment.center,
                padding: EdgeInsets.all(6.ap(context)),
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(
                    context.colorScheme,
                  ),
                  shape: AppShape.all(AppCorner.xl.ap(context) - _headerInset),
                ),
                clipBehavior: Clip.antiAlias,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: constraints.maxHeight - 12.ap(context),
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  child: icon,
                ),
              ),
            ),
          );
        },
      ),
      ProxiesIconStyle.plain => Container(
        margin: const EdgeInsets.only(left: 2, right: 10),
        child: LayoutBuilder(
          builder: (_, constraints) {
            return IconTheme.merge(
              data: IconThemeData(
                size: constraints.maxHeight,
                color: context.colorScheme.primary,
              ),
              child: icon,
            );
          },
        ),
      ),
      // Lines the title up with the proxy card names below, which sit at the
      // row inset plus the card padding.
      ProxiesIconStyle.hidden => const SizedBox(width: 4),
    };
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.groupName, required this.selectedName});
  final String groupName;
  final String selectedName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmojiText(
          groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.callout.of(context, emphasized: true),
        ),
        const SizedBox(height: 2),
        Flexible(flex: 1, child: _SelectedProxyName(proxyName: selectedName)),
      ],
    );
  }
}

class _SelectedProxyName extends StatelessWidget {
  const _SelectedProxyName({required this.proxyName});
  final String proxyName;

  @override
  Widget build(BuildContext context) {
    if (proxyName.isEmpty) {
      return const SizedBox.shrink();
    }
    return EmojiText(
      proxyName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.caption1.of(context, emphasized: true).toLight,
    );
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({
    required this.isExpand,
    required this.isDelayTesting,
    required this.groupType,
    required this.onScrollToSelected,
    required this.onDelayTest,
    required this.onToggle,
  });

  final bool isExpand;
  final bool isDelayTesting;
  final String groupType;
  final VoidCallback onScrollToSelected;
  final VoidCallback onDelayTest;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TonalButtonTheme(
      size: TonalButtonSize.compact,
      child: Row(
        children: [
          if (isExpand)
            TonalButtonGroup(
              size: TonalButtonSize.compact,
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).scrollToSelected,
                  onPressed: onScrollToSelected,
                  iconSize: 19,
                  icon: const GlyphIcon(AppGlyphs.locate),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).delayTest,
                  onPressed: isDelayTesting ? null : onDelayTest,
                  icon: isDelayTesting
                      ? CommonCircleLoading(size: TonalButtonSize.compact.icon)
                      : const GlyphIcon(AppGlyphs.bolt),
                ),
              ],
            )
          else
            Text(
              groupType,
              style: AppTextStyle.caption1
                  .of(context, emphasized: true)
                  .toLight,
            ),
          const SizedBox(width: 6),
          ElasticPress(
            child: IconButton(
              tooltip: isExpand
                  ? AppLocalizations.of(context).showLess
                  : AppLocalizations.of(context).showMore,
              onPressed: onToggle,
              icon: CommonExpandIcon(expand: isExpand),
            ),
          ),
        ],
      ),
    );
  }
}
