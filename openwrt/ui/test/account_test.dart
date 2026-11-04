import 'package:fl_clash/iping/pages/account_page.dart';
import 'package:fl_clash/iping/topup_history.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/app.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_client.dart';

Future<AppLocalizations> _openAccount(
  WidgetTester tester,
  FakeRouterClient client,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _Assets(),
      child: RouterApp(client: client),
    ),
  );
  await tester.pumpAndSettle();
  final l = AppLocalizations.current;
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationSidebar),
      matching: find.text(l.ipingProfileCenter),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(IpingAccountPage), findsOneWidget);
  return l;
}

void main() {
  testWidgets('the account page offers balance and top-up', (tester) async {
    final client = FakeRouterClient();
    final l = await _openAccount(tester, client);
    expect(find.text('¥128.50'), findsOneWidget);
    expect(find.text(l.ipingTopUp), findsOneWidget);
    expect(find.text(l.ipingTopupHistory), findsOneWidget);

    await tester.tap(find.text(l.ipingTopUp));
    await tester.pumpAndSettle();
    expect(find.text('Alipay'), findsOneWidget);
    expect(
      client.requests.any(
        (request) => request.$1 == 'api_call' && request.$2['path'] == 'pay',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('the account page opens the top-up history', (tester) async {
    final client = FakeRouterClient();
    final l = await _openAccount(tester, client);
    await tester.tap(find.text(l.ipingTopupHistory));
    await tester.pumpAndSettle();
    expect(find.byType(IpingTopupHistory), findsOneWidget);
    expect(find.text('Unpaid'), findsOneWidget);
    expect(
      client.requests.any(
        (request) => request.$1 == 'api_call' && request.$2['path'] == 'topup',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/fl_clash/$key' : key,
  );
}
