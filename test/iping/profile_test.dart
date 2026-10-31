import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/profile.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/topup.dart';
import 'package:fl_clash/iping/topup_form.dart';
import 'package:flutter/services.dart';
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

IpingTopupOrder _order(int id, IpingTopupStatus status) => IpingTopupOrder(
  id: id,
  price: 50,
  bonus: 5,
  status: status,
  paymentName: 'Alipay',
  payUrl: 'https://pay.example.com/$id',
  createdAt: DateTime.utc(2026, 10, 30, 8),
);

void main() {
  late FakeIpingApi api;
  late ProviderContainer container;
  final launched = <String>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            launched.add((call.arguments as Map)['url'] as String);
            return true;
          },
        );
    api = FakeIpingApi();
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingAuthenticatedApiProvider.overrideWithValue(api),
        ipingStorageProvider.overrideWithValue(
          MemorySessionStorage()..value = _account,
        ),
        ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Widget view) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: view),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the profile shows the balance and recent top-ups', (
    tester,
  ) async {
    api.topups = [
      _order(2, IpingTopupStatus.pending),
      _order(1, IpingTopupStatus.success),
    ];
    await pump(tester, const IpingProfile());
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('¥128.50'), findsOneWidget);
    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Joined 2026-10-22 · Telegram Linked'), findsOneWidget);
    expect(find.text('Top-up history'), findsNothing);
    expect(api.topupPageRequests.single.perPage, 10);

    await tester.tap(find.text('Unpaid'));
    await tester.pumpAndSettle();
    expect(launched, ['https://pay.example.com/2']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the profile charts traffic, lists referrals and warns of '
      'renewals the balance cannot cover', (tester) async {
    api.balance = 5;
    api.tunnels = [
      {
        'id': 1,
        'name': 'Tokyo',
        'status': 'active',
        'auto_renew': true,
        'expired_at': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
        'tunnel_price': {'name': 'Standard', 'price': 12},
      },
    ];
    await pump(tester, const IpingProfile());

    expect(find.text('Balance may not cover auto-renewals'), findsOneWidget);
    expect(
      find.text(
        '1 auto-renewing items cost about ¥12.00 within 7 days. '
        'Top up at least ¥7.00.',
      ),
      findsOneWidget,
    );

    expect(find.text('Traffic · Last 30 days'), findsOneWidget);
    expect(find.text('9 GB'), findsOneWidget);
    expect(find.text('7.5 GB'), findsOneWidget);
    final bars = find.byKey(const ValueKey('iping-traffic-bars'));
    expect(bars, paints..paragraph());
    await tester.tapAt(tester.getBottomRight(bars) - const Offset(2, 2));
    await tester.pump();
    expect(find.text('2026-10-30 · Billed traffic'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Referral link'), 200);
    expect(find.textContaining('?ref=7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('¥29.90'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the history pages through every order', (tester) async {
    api.topups = [
      for (var i = 45; i > 0; i--) _order(i, IpingTopupStatus.success),
    ];
    await pump(tester, const IpingTopupHistory());
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
    expect(api.topupPageRequests.map((r) => r.page), [1, 2, 3]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty history says so', (tester) async {
    await pump(tester, const IpingTopupHistory());
    expect(find.text('No top-ups yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('top-up validates the minimum and shows the bonus', (
    tester,
  ) async {
    await pump(tester, const IpingTopupForm());
    expect(find.text('Alipay'), findsOneWidget);
    expect(find.text('3% fee'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '5');
    await tester.tap(find.byTooltip('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount of at least ¥10.'), findsOneWidget);
    expect(api.createdTopups, isEmpty);

    await tester.tap(find.text('¥100'));
    await tester.pumpAndSettle();
    expect(find.text('¥110.00 · +¥10.00 bonus'), findsOneWidget);
    await tester.tap(find.byTooltip('Pay'));
    await tester.pumpAndSettle();
    expect(api.createdTopups.single, (price: 100.0, paymentId: 3));
    expect(launched, ['https://pay.example.com/order']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an unpaid order blocks a new one with a clear message', (
    tester,
  ) async {
    api.topupFailure = IpingFailure.unavailable;
    api.topupFailureStatus = 409;
    await pump(tester, const IpingTopupForm());
    await tester.tap(find.text('¥30'));
    await tester.tap(find.byTooltip('Pay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You have an unpaid order'), findsOneWidget);
    expect(launched, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
