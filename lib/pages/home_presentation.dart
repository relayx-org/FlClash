import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../enum/page_label.dart';
import '../ui/appearance.dart';
import '../ui/ui.dart';
import '../ui/icons/icons.dart';

class AppSidebarFrame extends StatelessWidget {
  const AppSidebarFrame({
    super.key,
    required this.hasSidebar,
    required this.sidebar,
    this.backgroundColor,
    this.chromeColor,
    this.onContentWidthChanged,
    required this.child,
  });

  final bool hasSidebar;
  final Widget sidebar;
  final Color? backgroundColor;
  final Color? chromeColor;
  final ValueChanged<double>? onContentWidthChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return Container(
      color: backgroundColor ?? SurfaceLevel.page.colorOf(context.colorScheme),
      child: Row(
        children: [
          AnimatedVisibility.sidebar(
            visible: hasSidebar,
            child: Material(
              color: chromeColor ?? context.colorScheme.chromeSurface,
              shape: BorderDirectional(end: Divider.createBorderSide(context)),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: !isLtr,
                removeRight: isLtr,
                child: sidebar,
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  onContentWidthChanged?.call(constraints.maxWidth);
                  return MediaQuery.removePadding(
                    context: context,
                    removeLeft: hasSidebar && isLtr,
                    removeRight: hasSidebar && !isLtr,
                    child: child,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeNavigationBody extends StatelessWidget {
  const HomeNavigationBody({
    super.key,
    required this.mobile,
    required this.floating,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
  });
  final bool mobile;
  final bool floating;
  final List<NavigationDockDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: SurfaceLevel.page.colorOf(context.colorScheme),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FocusTraversalGroup(
                    policy: PageTraversalPolicy(),
                    child: BottomInsetScope(
                      inset: mobile && floating
                          ? NavigationDock.insetOf(context)
                          : 0,
                      child: _BodyPadding(isMobile: mobile, child: child),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: AnimatedVisibility.bottomNavigation(
                    visible: mobile && floating,
                    child: _NavigationPadding(
                      child: NavigationDock(
                        destinations: [...destinations],
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedVisibility.bottomNavigation(
            visible: mobile && !floating,
            child: _NavigationPadding(
              child: NavigationBar(
                destinations: [
                  for (final (index, item) in destinations.indexed)
                    NavigationDestination(
                      icon: AnimatedGlyph(
                        glyph: item.glyph,
                        filled: index == selectedIndex,
                      ),
                      label: item.label,
                    ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyPadding extends StatelessWidget {
  const _BodyPadding({required this.isMobile, required this.child});

  final bool isMobile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      removeTop: false,
      removeBottom: isMobile,
      removeLeft: isMobile,
      removeRight: isMobile,
      context: context,
      child: child,
    );
  }
}

class _NavigationPadding extends StatelessWidget {
  const _NavigationPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      removeTop: true,
      removeBottom: false,
      removeLeft: true,
      removeRight: true,
      context: context,
      child: child,
    );
  }
}

class AppNavigationPage extends StatelessWidget {
  const AppNavigationPage({
    super.key,
    required this.id,
    required this.mobile,
    required this.active,
    required this.child,
  });
  final PageLabel id;
  final bool mobile;
  final bool active;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scoped = PageFocusScope(child: child);
    return PageActivityScope(
      isActive: active,
      child: TickerMode(
        enabled: active,
        child: ExcludeFocus(
          excluding: !active,
          child: KeyboardInsetHold(
            child: KeepScope(
              key: ValueKey(id),
              child: mobile
                  ? scoped
                  : Navigator(
                      key: ValueKey('${id.name}_navigator'),
                      pages: [MaterialPage(child: scoped)],
                      onDidRemovePage: (_) {},
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppPagesView extends StatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<PageLabel> labels;
  final PageLabel selectedPage;
  final bool mobile;
  final TabAnimation animation;

  const AppPagesView({
    required this.pageBuilder,
    super.key,
    required this.labels,
    required this.selectedPage,
    required this.mobile,
    required this.animation,
  });

  @override
  State<AppPagesView> createState() => _AppPagesViewState();
}

class _AppPagesViewState extends State<AppPagesView> {
  late PageController _pageController;

  List<int>? _order;
  int _slide = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void didUpdateWidget(covariant AppPagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.labels, widget.labels)) {
      _order = null;
      _updatePageController();
    } else if (oldWidget.selectedPage != widget.selectedPage) {
      unawaited(_toPage(widget.selectedPage));
    }
  }

  int get _pageIndex => _indexOf(widget.selectedPage);
  int _indexOf(PageLabel label) {
    final index = widget.labels.indexOf(label);
    if (index >= 0) return index;
    final settings = widget.labels.indexOf(PageLabel.tools);
    return settings >= 0 ? settings : 0;
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = _indexOf(pageLabel);
    if (index == -1) {
      return;
    }
    final tabAnimation = widget.animation;
    final isMobile = widget.mobile;
    final slide = ++_slide;
    final page = _pageController.hasClients
        ? _pageController.page?.round() ?? index
        : index;
    final current = _order?[page] ?? page;
    if (_order != null) {
      setState(() => _order = null);
      _pageController.jumpToPage(current);
    }
    if (!isMobile || ignoreAnimateTo) {
      _pageController.jumpToPage(index);
      return;
    }
    // As TabBarView does, so no page between is built and painted on the way.
    if ((index - current).abs() > 1) {
      final adjacent = index > current ? index - 1 : index + 1;
      setState(() {
        _order = List.generate(widget.labels.length, (item) => item)
          ..[adjacent] = current
          ..[current] = adjacent;
      });
      _pageController.jumpToPage(adjacent);
    }
    final fade = tabAnimation == TabAnimation.fade;
    await _pageController.animateToPage(
      index,
      duration: fade ? fadeTabDuration : kTabScrollDuration,
      curve: fade ? fadeTabCurve : Curves.easeOut,
    );
    if (mounted && slide == _slide && _order != null) {
      setState(() => _order = null);
    }
  }

  void _updatePageController() {
    final pageLabel = widget.selectedPage;
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.labels.length;
    final fade = widget.animation == TabAnimation.fade;
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<PageLabel>) {
          return null;
        }
        final index = widget.labels.indexOf(key.value);
        if (index == -1) {
          return null;
        }
        return _order?.indexOf(index) ?? index;
      },
      itemBuilder: (context, index) {
        final page = widget.pageBuilder(context, _order?[index] ?? index);
        return _FadeTabPage(
          key: page.key,
          controller: _pageController,
          position: index,
          enabled: fade,
          child: page,
        );
      },
    );
  }
}

/// Cancels the page view's slide so a tab switch cross-fades in place, and
/// wraps every page even when off so switching the setting keeps their state.
class _FadeTabPage extends StatelessWidget {
  const _FadeTabPage({
    super.key,
    required this.controller,
    required this.position,
    required this.enabled,
    required this.child,
  });

  final PageController controller;
  final int position;
  final bool enabled;
  final Widget child;

  double get _delta {
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return 0;
    }
    final page = controller.page ?? position.toDouble();
    return (position - page).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final offset = _delta;
        final delta = enabled ? offset : 0.0;
        return FractionalTranslation(
          translation: Offset(-delta, 0),
          child: Opacity(opacity: 1 - delta.abs(), child: child),
        );
      },
      child: child,
    );
  }
}
