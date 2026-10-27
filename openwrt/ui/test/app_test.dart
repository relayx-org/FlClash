import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/enum/mode.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/desktop_layout.dart';
import 'package:fl_clash/views/dashboard/panel_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/intranet_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_content.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/service_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/service_detail.dart';
import 'package:fl_clash/features/ip_quality/detail.dart';
import 'package:iping_openwrt/client.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/speed_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/mode_control.dart';
import 'package:fl_clash/views/settings_page.dart';
import 'package:fl_clash/views/proxies/list_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/app.dart';
import 'package:fl_clash/iping/login_page.dart';
import 'package:fl_clash/iping/subscription_page.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_client.dart';

void main() {
  testWidgets(
    'manual subscription import opens the dashboard without signing in',
    (tester) async {
      final client = FakeRouterClient(signedIn: false)..running = false;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.current;
      await tester.ensureVisible(find.text(l.ipingImportWithoutLogin));
      await tester.tap(find.text(l.ipingImportWithoutLogin));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'file:///tmp/sub');
      await tester.tap(find.text(l.submit));
      await tester.pumpAndSettle();
      expect(find.text(l.urlTip(l.url)), findsOneWidget);
      expect(client.calls, isNot(contains('import_subscription')));
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/sub',
      );
      await tester.tap(find.text(l.submit));
      await tester.pumpAndSettle();
      expect(find.byType(IpingLoginPage), findsNothing);
      expect(find.byType(DashboardProfileCard), findsOneWidget);
      expect(client.signedIn, isFalse);
      expect(client.calls, isNot(contains('account')));
      await tester.ensureVisible(find.byTooltip(l.details(l.profile)));
      await tester.tap(find.byTooltip(l.details(l.profile)));
      await tester.pumpAndSettle();
      expect(find.byType(IpingSubscriptionPage), findsOneWidget);
      expect(find.text(l.ipingManualSubscription), findsOneWidget);
      await tester.tap(find.text(l.ipingImportSubscription));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/new',
      );
      await tester.tap(find.text(l.submit));
      await tester.pumpAndSettle();
      expect(client.subscriptionUrl, 'https://example.com/new');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed manual imports restore login controls without browser prompts',
    (tester) async {
      final client = FakeRouterClient(signedIn: false)..running = false;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.current;
      await tester.ensureVisible(find.text(l.ipingImportWithoutLogin));
      await tester.tap(find.text(l.ipingImportWithoutLogin));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/sub',
      );
      client.importRequest = Completer<void>();
      client.failImport = true;
      await tester.tap(find.text(l.submit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.ipingBrowserWaiting), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      client.importRequest!.complete();
      await tester.pumpAndSettle();
      expect(find.text(l.ipingSubscriptionError), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline mode controls wait for completion and recover from failure',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = FakeRouterClient()..running = false;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final modeBar = find.byType(DashboardModeBar);
      final l = AppLocalizations.current;
      expect(tester.widget<DashboardModeBar>(modeBar).onChanged, isNotNull);
      client.modeRequest = Completer<void>();
      await tester.tap(
        find.descendant(of: modeBar, matching: find.text(l.global)),
      );
      await tester.pump();
      expect(tester.widget<DashboardModeBar>(modeBar).onChanged, isNull);
      client.modeRequest!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<DashboardModeBar>(modeBar).mode, Mode.global);
      expect(tester.widget<DashboardModeBar>(modeBar).onChanged, isNotNull);
      client.failMode = true;
      await tester.tap(
        find.descendant(of: modeBar, matching: find.text(l.direct)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<DashboardModeBar>(modeBar).mode, Mode.global);
      expect(tester.widget<DashboardModeBar>(modeBar).onChanged, isNotNull);
      expect(find.text(l.routerOperationFailed), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('opens iPing sign-in without a router access key', (
    tester,
  ) async {
    final client = FakeRouterClient(signedIn: false);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IpingLoginPage), findsOneWidget);
    expect(client.calls, contains('status'));
    expect(find.text('/usr/libexec/iping/agent token'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'desktop keeps the App sidebar and proxy interaction components',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final client = FakeRouterClient();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(ConnectionToggle), findsOneWidget);
      expect(find.byType(DashboardDesktopLayout), findsOneWidget);
      expect(find.byType(DashboardPanelLayout), findsOneWidget);
      expect(find.byType(DashboardOutboundCard), findsOneWidget);
      expect(find.byType(DashboardIntranetCard), findsOneWidget);
      expect(find.byType(DashboardProfileCard), findsOneWidget);
      expect(find.byType(DashboardServiceCard), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(DashboardIntranetCard),
          matching: find.byType(DashboardSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.settings['allow-lan'], isFalse);
      expect(find.byType(OutboundCardFrame), findsOneWidget);
      expect(find.byType(DashboardSpeedFrame), findsNWidgets(2));
      final l = AppLocalizations.current;
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationSidebar),
          matching: find.text(l.proxies),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProxyGroupsList), findsOneWidget);
      expect(find.byType(ProxyGroupHeader), findsOneWidget);
      expect(find.byType(ProxyCardFrame), findsNWidgets(2));
      client.calls.clear();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(client.calls, contains('telemetry'));
      expect(client.calls, isNot(contains('proxies')));
      await tester.tap(find.text('Node B'));
      await tester.pumpAndSettle();
      expect(client.selected, 'Node B');
      await tester.tap(find.text('30 ms').first);
      await tester.pumpAndSettle();
      expect(client.calls, contains('delay_proxy'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mobile uses the App floating dock and settings route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: FakeRouterClient()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDock), findsOneWidget);
    expect(find.byType(NavigationSidebar), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDock),
        matching: find.text(AppLocalizations.current.settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.ipingAccount), findsWidgets);
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.tap(find.text(AppLocalizations.current.theme));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceSettingsPage), findsOneWidget);
    expect(find.byType(NavigationDock).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('mobile settings keep text fonts and ignore telemetry updates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = FakeRouterClient();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationDock),
        matching: find.text(AppLocalizations.current.settings),
      ),
    );
    await tester.pumpAndSettle();
    final style = Theme.of(
      tester.element(find.byType(SettingsPage)),
    ).textTheme.bodyLarge!;
    expect(style.fontFamily, 'Roboto');
    expect(style.fontFamilyFallback, isNot(contains('Twemoji')));
    var settingsBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is SettingsPage) settingsBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    client.calls.clear();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(client.calls, contains('telemetry'));
    expect(settingsBuilds, 0);
    debugOnRebuildDirtyWidget = previous;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'mobile polling updates traffic without rebuilding static cards',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final client = FakeRouterClient();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final builds = <Type, int>{};
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        final type = element.widget.runtimeType;
        builds.update(type, (count) => count + 1, ifAbsent: () => 1);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      client.calls.clear();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(client.calls, contains('telemetry'));
      expect(client.calls, contains('dashboard'));
      expect(client.calls, isNot(contains('connections')));
      expect(client.calls, isNot(contains('proxies')));
      expect(builds[DashboardOutboundCard] ?? 0, 0);
      expect(builds[NavigationDock] ?? 0, 0);
      expect(builds[DashboardNetworkSpeedCard], greaterThan(0));
      debugOnRebuildDirtyWidget = previous;
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardServiceCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'dashboard probes use the shared cards, details and persisted service controls',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = FakeRouterClient();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _DependencyAssets(),
          child: RouterApp(client: client),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.current;
      final outbound = tester.widget<DashboardOutboundCard>(
        find.byType(DashboardOutboundCard),
      );
      expect(outbound.ip, '203.0.113.7');
      expect(outbound.organization, 'Test network');
      expect(outbound.typeLabel, l.ipTypeHosting);
      final services = tester.widget<DashboardServiceCard>(
        find.byType(DashboardServiceCard),
      );
      expect(services.services, hasLength(4));
      expect(
        services.services.every((service) => service.check?.delay == 42),
        isTrue,
      );
      expect(
        client.calls.where((method) => method == 'service_check'),
        hasLength(4),
      );

      await tester.tap(find.text('203.0.113.7'));
      await tester.pumpAndSettle();
      expect(find.byType(IpQualityDetail), findsOneWidget);
      await tester.tap(find.text(l.hideIp));
      await tester.pumpAndSettle();
      expect(client.preferences['hideIp'], isTrue);
      await tester.tap(find.byTooltip(l.close).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.serviceStatus));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCheckRow), findsWidgets);
      expect(
        client.calls.where((method) => method == 'service_check'),
        hasLength(4),
      );
      await tester.tap(find.byTooltip(l.serviceCheckAll).last);
      await tester.pumpAndSettle();
      expect(
        client.requests
            .where((item) => item.$1 == 'service_check')
            .any((item) => (item.$2['names'] as List).contains('netflix')),
        isTrue,
      );
      await tester.tap(find.byTooltip(l.serviceManage));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceManagePage), findsOneWidget);
      await tester.tap(find.text('Google').last);
      await tester.pumpAndSettle();
      expect(client.preferences['disabledServices'], contains('google'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed service probes show a failure and recover after retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _ServiceFailureClient();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    final services = find.byType(DashboardServiceCard);
    expect(
      tester
          .widget<DashboardServiceCard>(services)
          .services
          .every((service) => service.failed),
      isTrue,
    );
    client.failChecks = false;
    await tester.tap(find.byTooltip(AppLocalizations.current.serviceCheckAll));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardServiceCard>(services)
          .services
          .every((service) => service.check?.delay == 42),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('background tabs pause refreshes and resume failed probes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final client = _ServiceFailureClient();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    final calls = client.calls.length;
    await tester.pump(const Duration(seconds: 6));
    expect(client.calls.length, calls);
    client.failChecks = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardServiceCard>(find.byType(DashboardServiceCard))
          .services
          .every((service) => service.check?.delay == 42),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _DependencyAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/fl_clash/$key' : key,
  );
}

class _ServiceFailureClient extends FakeRouterClient {
  bool failChecks = true;
  @override
  Future<Object?> call(String method, [Map<String, Object?> args = const {}]) {
    if (method == 'service_check' && failChecks) {
      throw const RouterException('network_error');
    }
    return super.call(method, args);
  }
}
