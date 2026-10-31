import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fl_clash/ui/context.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/l10n.dart';
import 'package:fl_clash/ui/scroll_behavior.dart';
import 'package:fl_clash/ui/shape.dart';
import 'package:fl_clash/ui/surface.dart';
import 'package:fl_clash/ui/typography.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const _compactWidth = 48.0;
const _expandedWidth = 220.0;
const _itemSize = 40.0;
const _itemGap = 4.0;
const _verticalInset = 4.0;
const _maxSideInset = 12.0;
const _iconSize = 24.0;
const _labelGap = 12.0;
const _indicatorWidth = 3.0;
const _indicatorHeight = 16.0;
const _dividerVerticalPadding = 6.0;
const _dividerThickness = 1.0;
const _dividerHeight = _dividerVerticalPadding * 2 + _dividerThickness;
const _expandDuration = Duration(milliseconds: 250);
const _indicatorDuration = Duration(milliseconds: 320);
final _itemShape = AppShape.all(10);

class SidebarDestination {
  const SidebarDestination({
    required this.glyph,
    required this.label,
    this.group = 0,
  });

  final Glyph glyph;
  final String label;

  /// Destinations sharing a group stay together; a rule separates one group
  /// from the next.
  final int group;
}

class SidebarToggleScope extends InheritedWidget {
  const SidebarToggleScope({
    super.key,
    required this.progress,
    required this.onToggle,
    required super.child,
  });

  final double progress;

  final VoidCallback onToggle;

  static SidebarToggleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarToggleScope>();

  @override
  bool updateShouldNotify(SidebarToggleScope oldWidget) =>
      progress != oldWidget.progress;
}

class SidebarToggleButton extends StatelessWidget {
  const SidebarToggleButton({super.key, required this.toggle});

  final SidebarToggleScope toggle;

  @override
  Widget build(BuildContext context) {
    final localizations = UiLocalizations.of(context);
    return IconButton(
      tooltip: toggle.progress == 0
          ? localizations.showMore
          : localizations.showLess,
      onPressed: toggle.onToggle,
      icon: GlyphIcon(AppGlyphs.sidebar(toggle.progress)),
    );
  }
}

class NavigationSidebar extends StatefulWidget {
  const NavigationSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelected,
    this.onToggle,
    this.onToggleReady,
    this.windowControls = Size.zero,
    this.footer,
  });

  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelected;
  final VoidCallback? onToggle;

  /// Hands the parent the control that widens the pane or opens the overlay,
  /// and how far the pane has widened.
  final void Function(VoidCallback onToggle, double progress)? onToggleReady;
  final Size windowControls;
  final Widget? footer;

  @override
  State<NavigationSidebar> createState() => NavigationSidebarState();
}

class NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
  final _overlayController = OverlayPortalController();
  late final AnimationController _overlayExpansion = AnimationController(
    vsync: this,
    duration: _expandDuration,
  );
  late final CurvedAnimation _overlayProgress = CurvedAnimation(
    parent: _overlayExpansion,
    curve: Easing.standard,
  );

  @override
  void initState() {
    super.initState();
    _reportToggle();
  }

  void _reportToggle() {
    final report = widget.onToggleReady;
    if (report == null) return;
    final progress = widget.expanded ? 1.0 : _overlayExpansion.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) report(handleToggle, progress);
    });
  }

  @override
  void didUpdateWidget(covariant NavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reportToggle();
    if (widget.onToggle != null && _overlayController.isShowing) {
      _overlayExpansion.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hideIfDismissed());
    }
  }

  void handleToggle() {
    final onToggle = widget.onToggle;
    if (onToggle != null) {
      onToggle();
    } else if (_overlayExpansion.isForwardOrCompleted) {
      _closeOverlay();
    } else {
      _overlayController.show();
      _overlayExpansion.forward();
    }
    _reportToggle();
  }

  void _closeOverlay() {
    _overlayExpansion.reverse().whenCompleteOrCancel(_hideIfDismissed);
  }

  void _hideIfDismissed() {
    if (mounted && _overlayExpansion.isDismissed) {
      _overlayController.hide();
    }
  }

  @override
  void dispose() {
    _overlayProgress.dispose();
    _overlayExpansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return SidebarToggleScope(
      progress: widget.expanded ? 1 : 0,
      onToggle: handleToggle,
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlayController,
        overlayChildBuilder: (context, info) {
          return _SidebarOverlay(
            anchor: MatrixUtils.transformRect(
              info.childPaintTransform,
              Offset.zero & info.childSize,
            ),
            overlayWidth: info.overlaySize.width,
            progress: _overlayProgress,
            onDismiss: _closeOverlay,
            builder: (progress) => Padding(
              padding: safePadding,
              child: _SidebarPane(
                footer: widget.footer,
                progress: progress,
                windowControls: widget.windowControls,
                expanded: true,
                destinations: widget.destinations,
                selectedIndex: widget.selectedIndex,
                onSelected: (index) {
                  widget.onSelected(index);
                  _closeOverlay();
                },
                onToggle: _closeOverlay,
              ),
            ),
          );
        },
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.expanded ? 1.0 : 0.0),
            duration: _expandDuration,
            curve: Easing.standard,
            builder: (context, progress, _) => _SidebarPane(
              footer: widget.footer,
              progress: progress,
              windowControls: widget.windowControls,
              expanded: widget.expanded,
              destinations: widget.destinations,
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarOverlay extends StatelessWidget {
  const _SidebarOverlay({
    required this.anchor,
    required this.overlayWidth,
    required this.progress,
    required this.onDismiss,
    required this.builder,
  });

  final Rect anchor;
  final double overlayWidth;
  final Animation<double> progress;
  final VoidCallback onDismiss;
  final Widget Function(double progress) builder;

  @override
  Widget build(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    final colorScheme = context.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: isLtr ? anchor.left : null,
          right: isLtr ? null : overlayWidth - anchor.right,
          top: anchor.top,
          height: anchor.height,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            },
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    onDismiss();
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: Material(
                  color: colorScheme.chromeSurface,
                  shape: BorderDirectional(
                    end: Divider.createBorderSide(context),
                  ),
                  elevation: 8,
                  shadowColor: colorScheme.shadow,
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (_, _) => builder(progress.value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarColors {
  _SidebarColors(ColorScheme scheme)
    : selectedFill = scheme.onSurface.withValues(alpha: 0.08),
      label = scheme.onSurface,
      icon = scheme.onSurfaceVariant,
      indicator = scheme.primary,
      overlay = WidgetStateProperty.fromMap({
        WidgetState.pressed: scheme.onSurface.withValues(alpha: 0.06),
        WidgetState.focused: scheme.onSurface.withValues(alpha: 0.1),
        WidgetState.hovered: scheme.onSurface.withValues(alpha: 0.04),
        WidgetState.any: Colors.transparent,
      });

  final Color selectedFill;
  final Color label;
  final Color icon;
  final Color indicator;
  final WidgetStateProperty<Color> overlay;
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane({
    this.footer,
    required this.progress,
    required this.windowControls,
    required this.expanded,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.onToggle,
  });

  final double progress;
  final Widget? footer;
  final Size windowControls;
  final bool expanded;
  final List<SidebarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Set only for the pane drawn over the content, which closes itself.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = _SidebarColors(context.colorScheme);
    final fontSize = AppTextStyle.subheadline.size;
    final labelOpacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    final compactWidth = math.max(_compactWidth, windowControls.width);
    final sideInset = math.min(_maxSideInset, (compactWidth - _itemSize) / 2);
    final iconInset = (compactWidth - sideInset * 2 - _iconSize) / 2;
    final itemHeight =
        _itemSize + MediaQuery.textScalerOf(context).scale(fontSize) - fontSize;
    final rowWidth = _expandedWidth - sideInset * 2;
    final labelStyle = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colors.label);
    final labelWidth = rowWidth - iconInset - _iconSize - _labelGap * 2;
    String rowTooltip(String label) =>
        expanded &&
            progress == 1 &&
            _fitsOneLine(context, label, labelStyle, labelWidth)
        ? ''
        : label;
    return SizedBox(
      width: lerpDouble(compactWidth, _expandedWidth, progress),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: windowControls.height + _verticalInset),
          if (onToggle case final onToggle?)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SidebarButton(
                key: const ValueKey('overlay-toggle'),
                colors: colors,
                height: itemHeight,
                sideInset: sideInset,
                tooltip: UiLocalizations.of(context).showLess,
                onTap: onToggle,
                child: SizedBox(
                  width: compactWidth - sideInset * 2,
                  child: Center(child: GlyphIcon(AppGlyphs.sidebar(progress))),
                ),
              ),
            ),
          Expanded(
            child: ScrollConfiguration(
              behavior: const HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, destination)
                            in destinations.indexed) ...[
                          if (index > 0 &&
                              destination.group !=
                                  destinations[index - 1].group)
                            _SidebarDivider(sideInset: sideInset),
                          _SidebarButton(
                            key: ValueKey(destination.label),
                            colors: colors,
                            height: itemHeight,
                            sideInset: sideInset,
                            selected: index == selectedIndex,
                            tooltip: rowTooltip(destination.label),
                            onTap: () => onSelected(index),
                            child: _DestinationRow(
                              destination: destination,
                              selected: index == selectedIndex,
                              width: rowWidth,
                              iconInset: iconInset,
                              style: labelStyle,
                              labelOpacity: labelOpacity,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (selectedIndex < destinations.length)
                      _SelectionIndicator(
                        color: colors.indicator,
                        index: selectedIndex,
                        destinations: destinations,
                        start: sideInset,
                        stride: itemHeight + _itemGap,
                      ),
                  ],
                ),
              ),
            ),
          ),
          ?footer,
          const SizedBox(height: _verticalInset),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider({required this.sideInset});

  final double sideInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        sideInset,
        _dividerVerticalPadding,
        sideInset,
        _dividerVerticalPadding,
      ),
      child: const Divider(height: _dividerThickness),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    super.key,
    required this.colors,
    required this.height,
    required this.sideInset,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected,
  });

  final _SidebarColors colors;
  final double height;
  final double sideInset;
  final bool? selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sideInset,
        vertical: _itemGap / 2,
      ),
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        child: FocusRing(
          shape: _itemShape,
          child: Material(
            color: selected == true ? colors.selectedFill : Colors.transparent,
            shape: _itemShape,
            child: InkWell(
              onTap: onTap,
              customBorder: _itemShape,
              mouseCursor: SystemMouseCursors.basic,
              splashFactory: NoSplash.splashFactory,
              overlayColor: colors.overlay,
              child: Tooltip(
                message: tooltip,
                excludeFromSemantics: true,
                child: IconTheme.merge(
                  data: IconThemeData(size: _iconSize, color: colors.icon),
                  child: SizedBox(height: height, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _fitsOneLine(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: width);
  final fits = !painter.didExceedMaxLines;
  painter.dispose();
  return fits;
}

/// The row lays out at the expanded width whatever the pane's current width,
/// so the label is clipped rather than reflowed while the pane animates.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.selected,
    required this.width,
    required this.iconInset,
    required this.style,
    required this.labelOpacity,
  });

  final SidebarDestination destination;
  final bool selected;
  final double width;
  final double iconInset;
  final TextStyle? style;
  final double labelOpacity;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: width,
        maxWidth: width,
        child: Row(
          children: [
            SizedBox(width: iconInset),
            AnimatedGlyph(glyph: destination.glyph, filled: selected),
            const SizedBox(width: _labelGap),
            Expanded(
              child: Opacity(
                opacity: labelOpacity,
                alwaysIncludeSemantics: true,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            const SizedBox(width: _labelGap),
          ],
        ),
      ),
    );
  }
}

/// The indicator moves by stretching toward the new row before its trailing
/// edge catches up, rather than sliding at a fixed size.
class _SelectionIndicator extends StatefulWidget {
  const _SelectionIndicator({
    required this.color,
    required this.index,
    required this.destinations,
    required this.start,
    required this.stride,
  });

  final Color color;
  final int index;
  final List<SidebarDestination> destinations;
  final double start;
  final double stride;

  @override
  State<_SelectionIndicator> createState() => _SelectionIndicatorState();
}

class _SelectionIndicatorState extends State<_SelectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _indicatorDuration,
    value: 1,
  );
  late int _from = widget.index;

  @override
  void didUpdateWidget(covariant _SelectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _from = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _topOf(int index) {
    var dividers = 0;
    for (var i = 1; i <= index && i < widget.destinations.length; i++) {
      if (widget.destinations[i].group != widget.destinations[i - 1].group) {
        dividers++;
      }
    }
    return index * widget.stride +
        dividers * _dividerHeight +
        (widget.stride - _indicatorHeight) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final from = _topOf(_from);
        final to = _topOf(widget.index);
        final lead = Curves.easeOutCubic.transform(math.min(1, t / 0.6));
        final trail = Curves.easeInOutCubic.transform(
          math.max(0, (t - 0.35) / 0.65),
        );
        final (top, bottom) = to >= from
            ? (lerpDouble(from, to, trail)!, lerpDouble(from, to, lead)!)
            : (lerpDouble(from, to, lead)!, lerpDouble(from, to, trail)!);
        return PositionedDirectional(
          start: widget.start,
          top: top,
          width: _indicatorWidth,
          height: bottom - top + _indicatorHeight,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: widget.color,
            shape: AppShape.full,
          ),
        ),
      ),
    );
  }
}
