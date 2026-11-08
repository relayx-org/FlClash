import 'package:fl_clash/iping/subscription_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester, {
    String? exportUrl,
    bool manual = false,
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: IpingSubscriptionPage(
            nodes: manual ? 0 : 2,
            busy: false,
            manualUrl: manual
                ? 'https://example.com/sub?token=manual-token'
                : null,
            exportUrl: exportUrl,
            onSync: () {},
            onImport: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the account subscription export shows its link and QR code', (
    tester,
  ) async {
    const url = 'https://iping.my/api/tunnel/subscription?token=account-token';
    await pump(tester, exportUrl: url);

    await tester.tap(find.text('Export subscription'));
    await tester.pumpAndSettle();

    expect(find.text(url), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text(
        'The subscription link contains your account credential. '
        'Do not share it.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manual subscription has no account export', (tester) async {
    await pump(tester, manual: true);

    expect(find.text('Export subscription'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manual subscription masks its link and offers its actions', (
    tester,
  ) async {
    await pump(tester, manual: true);

    expect(find.text('example.com/••••••'), findsOneWidget);
    expect(find.textContaining('manual-token'), findsNothing);
    expect(find.text('Replace subscription link'), findsOneWidget);
    expect(find.text('Copy subscription link'), findsOneWidget);
    expect(find.text('Remove manual subscription'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
