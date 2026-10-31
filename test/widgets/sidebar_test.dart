import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/sidebar.dart';
import 'package:fl_clash/ui/surface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final _paneFinder = find
    .byWidgetPredicate((widget) => widget is Material && widget.elevation > 0)
    .first;

const _destinations = [
  SidebarDestination(glyph: AppGlyphs.dashboard, label: 'Dashboard'),
  SidebarDestination(glyph: AppGlyphs.proxies, label: 'Proxies'),
  SidebarDestination(glyph: AppGlyphs.profiles, label: 'Profiles'),
];

Finder _glyph(Glyph glyph) => find.byWidgetPredicate(
  (widget) => widget is AnimatedGlyph && widget.glyph == glyph,
);

double _fillOf(WidgetTester tester, Glyph glyph) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: _glyph(glyph), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as GlyphPainter).fill;
}

Widget _sidebar({
  List<SidebarDestination> destinations = _destinations,
  int selectedIndex = 0,
  bool expanded = true,
  ValueChanged<int>? onSelected,
  VoidCallback? onToggle,
  Size windowControls = Size.zero,
  EdgeInsets safePadding = EdgeInsets.zero,
  Widget? footer,
}) {
  return TestApp(
    child: Scaffold(
      body: Row(
        children: [
          SizedBox(
            height: 400,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: safePadding),
                child: NavigationSidebar(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  expanded: expanded,
                  onSelected: onSelected ?? (_) {},
                  onToggle: onToggle,
                  windowControls: windowControls,
                  footer: footer,
                ),
              ),
            ),
          ),
          const Expanded(child: SizedBox.expand(key: ValueKey('content'))),
        ],
      ),
    ),
  );
}

Finder get _sidebarFinder => find.byType(NavigationSidebar);

SidebarToggleScope _toggleOf(WidgetTester tester) => SidebarToggleScope.maybeOf(
  tester.element(
    find.descendant(of: _sidebarFinder, matching: find.byType(SafeArea)),
  ),
)!;

Finder _indicator(WidgetTester tester) {
  final primary = Theme.of(tester.element(_sidebarFinder)).colorScheme.primary;
  return find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is ShapeDecoration &&
        (widget.decoration as ShapeDecoration).color == primary,
  );
}

Finder _labels(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is Opacity && widget.alwaysIncludeSemantics,
  ),
);

Iterable<double> _labelOpacities(WidgetTester tester, String label) {
  return tester.widgetList<Opacity>(_labels(label)).map((o) => o.opacity);
}

Finder _shown(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Opacity &&
        widget.alwaysIncludeSemantics &&
        widget.opacity == 1,
  ),
  matching: find.text(label),
);

Finder _rowTooltip(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

void main() {
  testWidgets('a divider separates one group of destinations from the next', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sidebar(
        destinations: const [
          ..._destinations,
          SidebarDestination(
            glyph: AppGlyphs.account,
            label: 'Account',
            group: 1,
          ),
        ],
      ),
    );

    final divider = find.byType(Divider);
    expect(divider, findsOneWidget);
    final rule = tester.getCenter(divider);
    expect(
      rule.dy,
      greaterThan(tester.getCenter(_glyph(AppGlyphs.profiles)).dy),
    );
    expect(rule.dy, lessThan(tester.getCenter(_glyph(AppGlyphs.account)).dy));
  });

  testWidgets('keeps branding visible below the navigation at either width', (
    tester,
  ) async {
    for (final expanded in [false, true]) {
      await tester.pumpWidget(
        _sidebar(
          expanded: expanded,
          onToggle: () {},
          footer: const Center(
            child: SizedBox.square(dimension: 28, key: ValueKey('brand')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final brand = tester.getRect(find.byKey(const ValueKey('brand')));
      final sidebar = tester.getRect(_sidebarFinder);
      expect(brand.size, const Size.square(28));
      expect(sidebar.contains(brand.topLeft), isTrue);
      expect(sidebar.contains(brand.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the selected row carries a centered indicator', (tester) async {
    await tester.pumpWidget(_sidebar(selectedIndex: 1));

    final indicator = tester.getRect(_indicator(tester));
    expect(indicator.width, 3);
    expect(indicator.height, 16);
    expect(
      indicator.center.dy,
      moreOrLessEquals(tester.getCenter(_glyph(AppGlyphs.proxies)).dy),
    );
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(_labelOpacities(tester, 'Proxies'), [1]);
    expect(
      tester.getSemantics(find.text('Proxies')),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  testWidgets('the indicator stays centered when selected across a divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sidebar(
        selectedIndex: 3,
        destinations: const [
          ..._destinations,
          SidebarDestination(
            glyph: AppGlyphs.account,
            label: 'Account',
            group: 1,
          ),
        ],
      ),
    );

    final indicator = tester.getRect(_indicator(tester));
    expect(
      indicator.center.dy,
      moreOrLessEquals(tester.getCenter(_glyph(AppGlyphs.account)).dy),
    );
  });

  testWidgets('the indicator stretches toward the new row and settles on it', (
    tester,
  ) async {
    await tester.pumpWidget(_sidebar());
    final start = tester.getRect(_indicator(tester));

    await tester.pumpWidget(_sidebar(selectedIndex: 2));
    await tester.pump(const Duration(milliseconds: 160));
    final middle = tester.getRect(_indicator(tester));
    expect(middle.top, greaterThanOrEqualTo(start.top));
    expect(middle.height, greaterThan(16));

    await tester.pumpAndSettle();
    final end = tester.getRect(_indicator(tester));
    expect(end.height, 16);
    expect(
      end.center.dy,
      moreOrLessEquals(tester.getCenter(_glyph(AppGlyphs.profiles)).dy),
    );
  });

  testWidgets('only the selected row fills its icon', (tester) async {
    await tester.pumpWidget(_sidebar());
    expect(_fillOf(tester, AppGlyphs.dashboard), 1);
    expect(_fillOf(tester, AppGlyphs.profiles), 0);

    await tester.pumpWidget(_sidebar(selectedIndex: 2));
    await tester.pumpAndSettle();
    expect(_fillOf(tester, AppGlyphs.dashboard), 0);
    expect(_fillOf(tester, AppGlyphs.profiles), 1);
  });

  testWidgets('the toggle widens the sidebar in place when it can', (
    tester,
  ) async {
    var toggled = 0;
    int? selected;
    await tester.pumpWidget(
      _sidebar(
        expanded: false,
        onToggle: () => toggled++,
        onSelected: (index) => selected = index,
      ),
    );

    expect(tester.getSize(_sidebarFinder).width, 48);
    expect(_labelOpacities(tester, 'Proxies'), [0]);
    expect(_rowTooltip('Proxies'), findsOneWidget);
    await tester.tap(_glyph(AppGlyphs.profiles));
    expect(selected, 2);

    final toggle = _toggleOf(tester);
    expect(toggle.progress, 0);
    toggle.onToggle();
    expect(toggled, 1);

    await tester.pumpWidget(_sidebar(onToggle: () {}));
    await tester.pump(const Duration(milliseconds: 120));
    final width = tester.getSize(_sidebarFinder).width;
    expect(width, allOf(greaterThan(48), lessThan(220)));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(_rowTooltip('Proxies'), findsNothing);
    expect(_toggleOf(tester).progress, 1);
  });

  testWidgets('an expanded row whose label is cut off keeps its tooltip', (
    tester,
  ) async {
    const long = 'Подключения и активные соединения';
    await tester.pumpWidget(
      _sidebar(
        destinations: const [
          ..._destinations,
          SidebarDestination(glyph: AppGlyphs.connections, label: long),
        ],
        onToggle: () {},
      ),
    );

    expect(_rowTooltip(long), findsOneWidget);
    expect(_rowTooltip('Proxies'), findsNothing);
  });

  testWidgets('the toggle glyph follows the pane as it widens', (tester) async {
    await tester.pumpWidget(_sidebar(expanded: false, onToggle: () {}));
    expect(_toggleOf(tester).progress, 0);

    await tester.pumpWidget(_sidebar(onToggle: () {}));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      _labelOpacities(tester, 'Proxies').single,
      allOf(greaterThan(0), lessThan(1)),
    );

    await tester.pumpAndSettle();
    expect(_toggleOf(tester).progress, 1);
  });

  testWidgets('window controls keep their corner clear', (tester) async {
    await tester.pumpWidget(
      _sidebar(
        expanded: false,
        onToggle: () {},
        windowControls: const Size(78, 32),
      ),
    );

    final sidebar = tester.getRect(_sidebarFinder);
    expect(sidebar.width, 78);
    expect(
      tester.getTopLeft(_glyph(AppGlyphs.dashboard)).dy,
      greaterThanOrEqualTo(sidebar.top + 32),
    );
    expect(tester.getCenter(_glyph(AppGlyphs.profiles)).dx, sidebar.center.dx);
    final selectedItem = tester.getRect(
      find
          .ancestor(
            of: _glyph(AppGlyphs.dashboard),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(selectedItem.size, const Size(54, 40));
    expect(selectedItem.center.dx, sidebar.center.dx);

    final folder = tester.getCenter(_glyph(AppGlyphs.profiles));
    await tester.pumpWidget(
      _sidebar(onToggle: () {}, windowControls: const Size(78, 32)),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebarFinder).width, 220);
    expect(tester.getCenter(_glyph(AppGlyphs.profiles)).dx, folder.dx);
  });

  group('without room to widen', () {
    Future<void> openOverlay(WidgetTester tester) async {
      _toggleOf(tester).onToggle();
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsNWidgets(2));
    }

    final overlayToggle = find.byKey(const ValueKey('overlay-toggle'));

    testWidgets('the toggle opens the pane over the content', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      final contentWidth = tester
          .getSize(find.byKey(const ValueKey('content')))
          .width;

      await openOverlay(tester);

      expect(tester.getSize(_sidebarFinder).width, 48);
      expect(
        tester.getSize(find.byKey(const ValueKey('content'))).width,
        contentWidth,
      );
      expect(_labelOpacities(tester, 'Proxies'), unorderedEquals([0, 1]));
      expect(overlayToggle, findsOneWidget);
      final colorScheme = Theme.of(tester.element(_sidebarFinder)).colorScheme;
      final pane = tester.widget<Material>(_paneFinder);
      expect(pane.color, colorScheme.chromeSurface);
      expect(
        (pane.shape! as BorderDirectional).end,
        Divider.createBorderSide(tester.element(_sidebarFinder)),
      );

      await tester.tap(overlayToggle);
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);
    });

    testWidgets('the pane covers the safe area around the sidebar', (
      tester,
    ) async {
      const safePadding = EdgeInsets.only(left: 40, top: 24, bottom: 16);
      await tester.pumpWidget(
        _sidebar(expanded: false, safePadding: safePadding),
      );
      final sidebar = tester.getRect(_sidebarFinder);
      expect(sidebar.width, 48 + safePadding.left);
      final firstRow = tester.getTopLeft(_glyph(AppGlyphs.dashboard));
      expect(
        firstRow.dx,
        greaterThanOrEqualTo(sidebar.left + safePadding.left),
      );
      expect(firstRow.dy, greaterThanOrEqualTo(sidebar.top + safePadding.top));

      await openOverlay(tester);

      final pane = tester.getRect(_paneFinder);
      expect(pane.topLeft, sidebar.topLeft);
      expect(pane.height, sidebar.height);
      expect(pane.width, 220 + safePadding.left);
    });

    testWidgets('choosing a row selects it and closes the pane', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        _sidebar(expanded: false, onSelected: (index) => selected = index),
      );
      await openOverlay(tester);

      await tester.tap(_shown('Profiles'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(find.text('Profiles'), findsOneWidget);
    });

    testWidgets('a tap outside or escape dismisses the pane', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));

      await openOverlay(tester);
      await tester.tapAt(const Offset(600, 300));
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);

      await openOverlay(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Proxies'), findsOneWidget);
    });

    testWidgets('a tooltip inside the pane lays out over it', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      await openOverlay(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: tester.getCenter(_shown('Proxies')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Proxies'), findsWidgets);
    });

    testWidgets('widening the window closes the pane', (tester) async {
      await tester.pumpWidget(_sidebar(expanded: false));
      await openOverlay(tester);

      await tester.pumpWidget(_sidebar(expanded: false, onToggle: () {}));
      await tester.pump();
      expect(find.text('Proxies'), findsOneWidget);
    });
  });
}
