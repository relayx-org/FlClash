import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/iping/pages/dashboard_page.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/desktop_layout.dart';
import 'package:fl_clash/iping/widgets/dashboard_card_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Preferences implements IpingDashboardPreferences {
  @override
  bool get hideIp => false;

  @override
  List<String> get serviceOrder => const [];

  @override
  List<String> get disabledServices => const [];
}

class _OutboundProbe implements IpingDashboardOutboundProbe {
  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  RoutedProbeState<String, IpInfo> get state =>
      const RoutedProbeState<String, IpInfo>();

  @override
  IpQuality? qualityOf(String ip) => null;

  @override
  bool isQualityLoading(String ip) => false;

  @override
  void refreshOutbound() {}
}

class _ServiceProbe implements IpingDashboardServiceProbe {
  @override
  void watch(ServiceTarget target) {}

  @override
  void unwatch(ServiceTarget target) {}

  @override
  void refresh(Iterable<ServiceTarget> targets) {}

  @override
  RoutedProbeState<ServiceTarget, ServiceCheck> get state =>
      const RoutedProbeState<ServiceTarget, ServiceCheck>();
}

class _Probes extends ChangeNotifier implements IpingDashboardProbes {
  @override
  final IpingDashboardOutboundProbe outbound = _OutboundProbe();

  @override
  final IpingDashboardServiceProbe services = _ServiceProbe();

  @override
  Object? get error => null;
}

class _Editor implements IpingDashboardEditor {
  _Editor(this._all, {List<String>? visible})
    : _visible = [
        ...visible ?? [for (final card in _all) card.id],
      ];

  final List<IpingDashboardCard> _all;
  List<String> _visible;
  List<String> saved = [];
  int resets = 0;
  VoidCallback? changed;

  IpingDashboardCard _byId(String id) =>
      _all.firstWhere((card) => card.id == id);

  @override
  List<IpingDashboardCard> get cards => [for (final id in _visible) _byId(id)];

  @override
  List<IpingDashboardCard> get available => [
    for (final card in _all)
      if (!_visible.contains(card.id)) card,
  ];

  @override
  List<IpingDashboardCard> get desktopCards => _all;

  @override
  void save(List<String> ids) {
    saved = [...ids];
    _visible = [...ids];
    changed?.call();
  }

  @override
  void reset() {
    resets++;
    _visible = [for (final card in _all) card.id];
    saved = [..._visible];
    changed?.call();
  }
}

class _Takeover implements IpingNetworkTakeover {
  @override
  bool get supportsSystemProxy => true;

  @override
  bool get supportsTun => true;

  @override
  bool get systemProxy => false;

  @override
  bool get tun => false;

  @override
  Future<void> setSystemProxy(bool value) async {}

  @override
  Future<void> setTun(bool value) async {}
}

class _Host extends ChangeNotifier implements IpingDashboardHost {
  _Host(this.editor);

  final IpingDashboardEditor? editor;
  final _probes = _Probes();

  @override
  IpingNetworkTakeover get networkTakeover => _Takeover();

  @override
  IpingDashboardEditor? get dashboardEditor => editor;

  @override
  IpingDashboardPreferences get preferences => _Preferences();

  @override
  IpingDashboardProbes get probes => _probes;

  @override
  bool get visible => false;

  @override
  bool get busy => false;

  @override
  bool get connected => false;

  @override
  bool get hasSubscription => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DefaultHost extends ChangeNotifier implements IpingDashboardHost {
  final _probes = _Probes();
  @override
  final telemetryUpdates = ChangeNotifier();
  List<String> saved = [];

  @override
  IpingDashboardEditor? get dashboardEditor => null;

  @override
  List<String>? get dashboardCards => saved;

  @override
  void saveDashboardCards(List<String> ids) {
    saved = [...ids];
    notifyListeners();
  }

  @override
  IpingDashboardPreferences get preferences => _Preferences();

  @override
  IpingDashboardProbes get probes => _probes;

  @override
  IpingNetworkTakeover get networkTakeover => _Takeover();

  @override
  IpingTelemetry get telemetry => const IpingTelemetry();

  @override
  IpingTrafficSnapshot get traffic => const IpingTrafficSnapshot.empty();

  @override
  bool get visible => false;

  @override
  bool get busy => false;

  @override
  bool get connected => false;

  @override
  bool get hasSubscription => false;

  @override
  bool get suspended => false;

  @override
  int get nodes => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

IpingDashboardCard _card(
  String id,
  String label, {
  bool removable = true,
  List<IpingDashboardDesktopCard> desktop = const [],
}) => IpingDashboardCard(
  id: id,
  label: (_) => label,
  glyph: AppGlyphs.dashboard,
  removable: removable,
  builder: (_) => SizedBox(height: 80, child: Text('card:$label')),
  desktop: desktop,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(
    WidgetTester tester,
    IpingDashboardHost host, {
    Size size = const Size(412, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: IpingDashboardScope(
            host: host,
            child: const IpingDashboardPage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The cards sway for as long as they are edited, so nothing settles.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('shows the host cards in order and edits their arrangement', (
    tester,
  ) async {
    final cards = [
      _card('currentOutbound', 'Status', removable: false),
      _card('networkSpeed', 'Network speed'),
      _card('memoryInfo', 'Memory info'),
    ];
    final editor = _Editor(cards);
    final host = _Host(editor);
    editor.changed = host.notifyListeners;
    await pumpPage(tester, host);

    expect(find.text('card:Status'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('card:Status')).dy,
      lessThan(tester.getTopLeft(find.text('card:Network speed')).dy),
    );
    expect(
      tester.getTopLeft(find.text('card:Network speed')).dy,
      lessThan(tester.getTopLeft(find.text('card:Memory info')).dy),
    );

    await tester.tap(find.byTooltip('Edit dashboard'));
    await settle(tester);

    expect(find.byType(IpingDashboardCardEditor), findsOneWidget);
    expect(find.byTooltip('Remove Status'), findsNothing);
    expect(find.byTooltip('Remove Network speed'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Network speed'));
    await settle(tester);

    expect(editor.saved, ['currentOutbound', 'memoryInfo']);
    expect(find.text('card:Network speed'), findsNothing);
    expect(find.byTooltip('Add Network speed'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Network speed'));
    await settle(tester);

    expect(editor.saved, ['currentOutbound', 'memoryInfo', 'networkSpeed']);

    await tester.tap(find.byTooltip('Reset'));
    await settle(tester);

    expect(editor.resets, 1);
    expect(editor.saved, ['currentOutbound', 'networkSpeed', 'memoryInfo']);

    await tester.tap(find.byTooltip('Done'));
    await settle(tester);

    expect(find.byType(IpingDashboardCardEditor), findsNothing);
    expect(find.byTooltip('Edit dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('edits and persists the page cards when the host has none', (
    tester,
  ) async {
    final host = _DefaultHost();
    await pumpPage(tester, host, size: const Size(412, 2400));

    expect(find.byTooltip('Edit dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit dashboard'));
    await settle(tester);

    expect(find.byType(IpingDashboardCardEditor), findsOneWidget);
    expect(find.byTooltip('Remove Status'), findsNothing);

    await tester.tap(find.byTooltip('Remove Service status'));
    await settle(tester);

    expect(host.saved, isNot(contains('services')));
    expect(find.byTooltip('Add Service status'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Service status'));
    await settle(tester);

    expect(host.saved.last, 'services');

    await tester.tap(find.byTooltip('Reset'));
    await settle(tester);

    expect(host.saved, [
      'currentOutbound',
      'networkSpeed',
      'outboundMode',
      'networkTakeover',
      'intranet',
      'services',
      'profile',
      'proxyGroups',
      'connections',
    ]);

    await tester.tap(find.byTooltip('Done'));
    await settle(tester);

    expect(find.byType(IpingDashboardCardEditor), findsNothing);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });

  testWidgets('the wide layout places the host desktop cards without editing', (
    tester,
  ) async {
    final cards = [
      _card(
        'outbound',
        'Outbound',
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.outbound,
            builder: (_) => const Text('wide:Outbound'),
          ),
        ],
      ),
      _card(
        'speed',
        'Speed',
        desktop: const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.upload,
            builder: _upload,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.download,
            builder: _download,
          ),
        ],
      ),
      _card(
        'mode',
        'Mode',
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.mode,
            builder: (_) => const Text('wide:Mode'),
          ),
        ],
      ),
      _card(
        'intranet',
        'Intranet',
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: (_) => const Text('wide:Intranet'),
          ),
        ],
      ),
      _card(
        'connections',
        'Connections',
        desktop: [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.summary,
            builder: (_) => const Text('wide:Connections'),
          ),
        ],
      ),
    ];
    final editor = _Editor(cards);
    final host = _Host(editor);
    editor.changed = host.notifyListeners;
    await pumpPage(tester, host, size: const Size(1220, 900));

    expect(find.byType(DashboardDesktopLayout), findsOneWidget);
    expect(find.text('wide:Outbound'), findsOneWidget);
    expect(find.text('wide:Upload'), findsOneWidget);
    expect(find.text('wide:Download'), findsOneWidget);
    expect(find.text('wide:Mode'), findsOneWidget);
    expect(find.text('wide:Intranet'), findsOneWidget);
    expect(find.text('wide:Connections'), findsOneWidget);
    expect(find.byTooltip('Edit dashboard'), findsNothing);
    expect(find.byType(IpingDashboardCardEditor), findsNothing);
    expect(tester.takeException(), isNull);

    await teardown(tester);
  });
}

Widget _upload(BuildContext context) => const Text('wide:Upload');

Widget _download(BuildContext context) => const Text('wide:Download');
