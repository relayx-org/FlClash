import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/iping/diagnostics.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import 'fakes.dart';

const _account = IpingAccount(
  id: 7,
  email: 'test@example.com',
  subscriptionToken: 'test',
  apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
);

class _Ips extends OutboundIpProbe {
  int watchers = 0;
  int refreshes = 0;
  @override
  RoutedProbeState<String, IpInfo> build() => const RoutedProbeState({
    routedOutbound: ProbeEntry(
      phase: ProbePhase.fresh,
      value: IpInfo(ip: '192.0.2.1', countryCode: 'JP'),
    ),
  });
  @override
  void watch(String target) => watchers++;
  @override
  void unwatch(String target) => watchers--;
  @override
  void refresh(Iterable<String> targets) => refreshes++;
  void fail() => state = const RoutedProbeState({
    routedOutbound: ProbeEntry(phase: ProbePhase.failed),
  });
}

void main() {
  late ProviderContainer container;
  late FakeIpingApi api;
  late _Ips ips;
  var dnsOk = true;
  var dnsRequests = 0;
  var safe = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeIpingApi();
    ips = _Ips();
    dnsOk = true;
    dnsRequests = 0;
    safe = false;
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingAuthenticatedApiProvider.overrideWithValue(api),
        ipingStorageProvider.overrideWithValue(
          MemorySessionStorage()..value = _account,
        ),
        ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
        outboundIpProbeProvider.overrideWith(() => ips),
        safeModeProvider.overrideWith((_) => safe),
        ipingDnsProvider.overrideWith((_) async {
          dnsRequests++;
          return dnsOk;
        }),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Widget view) async {
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: view),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('manual subscriptions omit account authorization checks', (
    tester,
  ) async {
    final session = container.read(ipingSessionProvider.notifier).controller;
    await session.initialize();
    await session.signOut();
    await session.importSubscription('https://example.com/sub');
    await pump(tester, const IpingDiagnostics());
    expect(find.text('API Key'), findsNothing);
    expect(api.userInfoRequests, 0);
    expect(find.text('Refresh subscription'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'diagnostics fit narrow Russian text and reduced motion in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await container
            .read(ipingSessionProvider.notifier)
            .controller
            .initialize();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        safe = true;
        for (final page in const [IpingDiagnostics()]) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: TestApp(
                locale: const Locale('ru'),
                theme: ThemeData(
                  colorScheme: seededColorScheme(
                    seedColor: const Color(0xFF146B65),
                    brightness: brightness,
                  ),
                ).withAppShapes.withAppSurfaces.withAppTypography,
                child: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -1500),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
        }
      },
    );
  }

  testWidgets(
    'diagnostics reuse the exit probe, retry checks and release their watcher',
    (tester) async {
      container.read(runTimeProvider.notifier).value = 1;
      await pump(tester, const IpingDiagnostics());
      expect(
        find.text('Server address resolved successfully.'),
        findsOneWidget,
      );
      expect(
        find.text('The current exit responded successfully.'),
        findsOneWidget,
      );
      expect(ips.watchers, 1);
      await tester.tap(find.byTooltip('Check again'));
      await tester.pumpAndSettle();
      expect(dnsRequests, 2);
      expect(api.userInfoRequests, 2);
      expect(ips.refreshes, 1);
      ips.fail();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The exit did not respond. Try another node and check again.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(ips.watchers, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'safe mode and DNS failure are shown explicitly and remain retryable',
    (tester) async {
      safe = true;
      dnsOk = false;
      api.userInfoFailure = IpingFailure.session;
      await pump(tester, const IpingDiagnostics());
      expect(
        find.text('Safe mode: proxy and exit checks are unavailable.'),
        findsNWidgets(2),
      );
      expect(
        find.text('Your session is no longer valid. Please sign in again.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Unable to resolve the server address.'),
        findsOneWidget,
      );
      expect(ips.watchers, 0);
      dnsOk = true;
      api.userInfoFailure = null;
      await tester.tap(find.byTooltip('Check again'));
      await tester.pumpAndSettle();
      expect(
        find.text('Server address resolved successfully.'),
        findsOneWidget,
      );
      expect(ips.refreshes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
