import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/enum/mode.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/desktop_layout.dart';
import 'package:fl_clash/views/dashboard/widgets/outbound_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/speed_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/mode_control.dart';
import 'package:fl_clash/views/settings_page.dart';
import 'package:fl_clash/views/proxies/list_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/app.dart';
import 'package:iping_openwrt/access.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_client.dart';

void main() {
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

  testWidgets('owner key gates API calls and permits retry', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = FakeRouterClient()..authorized = false;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RouterAccessPage), findsOneWidget);
    expect(client.calls, isEmpty);
    final l = AppLocalizations.current;
    await tester.enterText(find.byType(TextFormField), 'wrong-key');
    await tester.tap(find.text(l.submit));
    await tester.pumpAndSettle();
    expect(find.text(l.routerAccessInvalid), findsOneWidget);
    expect(client.calls, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'test-key');
    await tester.tap(find.text(l.submit));
    await tester.pumpAndSettle();
    expect(find.byType(RouterAccessPage), findsNothing);
    expect(find.byType(NavigationSidebar), findsOneWidget);
    expect(client.calls, contains('status'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('owner authorization failure clears busy and can retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = FakeRouterClient()..failAuthorization = true;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _DependencyAssets(),
        child: RouterApp(client: client),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.current;
    expect(find.text(l.routerAgentUnavailable), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, l.submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    client.failAuthorization = false;
    await tester.enterText(find.byType(TextFormField), 'test-key');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(RouterAccessPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('pending owner authorization tolerates disposal', (tester) async {
    final pending = Completer<bool>();
    final client = FakeRouterClient()..authorization = pending;
    await tester.pumpWidget(RouterApp(client: client));
    await tester.pump();
    expect(client.calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    expect(tester.takeException(), isNull);
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
}

class _DependencyAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/fl_clash/$key' : key,
  );
}
