import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/popup_notice.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import 'fakes.dart';

const _account = IpingAccount(
  id: 7,
  email: 'user@example.com',
  subscriptionToken: 'subscription',
  apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
);

void main() {
  late FakeIpingApi api;
  late MemorySessionStorage storage;
  late ProviderContainer container;

  setUp(() {
    api = FakeIpingApi()..popupNoticeText = '**Maintenance** tonight';
    storage = MemorySessionStorage()..value = _account;
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingAuthenticatedApiProvider.overrideWithValue(api),
        ipingStorageProvider.overrideWithValue(storage),
        ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: IpingPopupNotice(child: Scaffold(body: Text('HOME'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void resume(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('a signed-in launch shows the notice once per cooldown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.byType(IpingPopupNoticeDialog), findsOneWidget);
    expect(find.textContaining('Maintenance'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(IpingPopupNoticeDialog), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt(ipingPopupNoticeShownKey), isNotNull);

    resume(tester);
    await tester.pumpAndSettle();
    expect(find.byType(IpingPopupNoticeDialog), findsNothing);
    expect(api.popupNoticeRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a notice dismissed before the cooldown is not requested', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ipingPopupNoticeShownKey: DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    });
    await pump(tester);
    expect(find.byType(IpingPopupNoticeDialog), findsNothing);
    expect(api.popupNoticeRequests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an expired cooldown shows the notice again', (tester) async {
    SharedPreferences.setMockInitialValues({
      ipingPopupNoticeShownKey: DateTime.now()
          .subtract(ipingPopupNoticeCooldown + const Duration(minutes: 1))
          .millisecondsSinceEpoch,
    });
    await pump(tester);
    expect(find.byType(IpingPopupNoticeDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('blank notices and signed-out sessions show nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    api.popupNoticeText = '';
    await pump(tester);
    expect(find.byType(IpingPopupNoticeDialog), findsNothing);
    expect(api.popupNoticeRequests, 1);

    await container.read(ipingSessionProvider.notifier).controller.signOut();
    api.popupNoticeText = 'Hello';
    resume(tester);
    await tester.pumpAndSettle();
    expect(find.byType(IpingPopupNoticeDialog), findsNothing);
    expect(api.popupNoticeRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
