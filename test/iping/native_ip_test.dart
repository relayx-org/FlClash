import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/store_widgets.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/keyboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import 'fakes.dart';

Future<void> _sendFind(WidgetTester tester) async {
  final modifier = controlSingleActivator(LogicalKeyboardKey.keyF).meta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Map<String, Object?> _offer({
  required String country,
  required String cityName,
  required String city,
  required String countryCode,
  required int stock,
  required num price,
  List<Map<String, Object>> tags = const [],
}) => {
  'country_code': countryCode,
  'country': country,
  'city_name': cityName,
  'city': city,
  'number': stock,
  'price': price,
  'tags': tags,
};

void main() {
  late FakeIpingApi api;
  late ProviderContainer container;

  setUp(() {
    api = FakeIpingApi();
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingAuthenticatedApiProvider.overrideWithValue(api),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          withStatusManager: true,
          child: IpingNativeIpPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('inventory lists stock and leaves sold-out regions closed', (
    tester,
  ) async {
    api.nativeInventory['ipproxy/inventory/native'] = [
      _offer(
        country: 'United States',
        cityName: 'Los Angeles',
        city: 'los-angeles',
        countryCode: 'US',
        stock: 2,
        price: 12,
        tags: const [
          {'label': 'Residential'},
        ],
      ),
    ];
    api.nativeInventory['ipproxy/inventory/native2'] = [
      _offer(
        country: 'Japan',
        cityName: 'Tokyo',
        city: 'tokyo',
        countryCode: 'JP',
        stock: 0,
        price: 9,
      ),
    ];

    await pump(tester);

    expect(find.text('Japan · Tokyo'), findsOneWidget);
    expect(find.textContaining('Sold out'), findsOneWidget);
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.textContaining('2 in stock'), findsOneWidget);
    expect(find.textContaining('Residential'), findsWidgets);
    expect(find.byGlyph(AppGlyphs.chevronForward), findsOneWidget);

    await tester.tap(find.text('Japan · Tokyo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Buy'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search matches country, city, line and tags', (tester) async {
    api.nativeInventory['ipproxy/inventory/native'] = [
      _offer(
        country: 'United States',
        cityName: 'Los Angeles',
        city: 'los-angeles',
        countryCode: 'US',
        stock: 2,
        price: 12,
        tags: const [
          {'label': 'Residential'},
        ],
      ),
    ];
    api.nativeInventory['ipproxy/inventory/native3'] = [
      _offer(
        country: 'Japan',
        cityName: 'Tokyo',
        city: 'tokyo',
        countryCode: 'JP',
        stock: 1,
        price: 9,
      ),
    ];
    await pump(tester);

    await _sendFind(tester);
    await tester.enterText(find.byType(TextField), 'residential');
    await tester.pumpAndSettle();
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.text('Japan · Tokyo'), findsNothing);

    await tester.enterText(find.byType(TextField), 'line c');
    await tester.pumpAndSettle();
    expect(find.text('Japan · Tokyo'), findsOneWidget);
    expect(find.text('United States · Los Angeles'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.noSearchResults), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed inventory can be retried', (tester) async {
    api.nativeInventoryFailure = IpingFailure.unavailable;
    await pump(tester);
    expect(
      find.text('Unable to load native IPs. Please try again.'),
      findsOneWidget,
    );

    api.nativeInventoryFailure = null;
    api.nativeInventory['ipproxy/inventory/native2'] = [
      _offer(
        country: 'Japan',
        cityName: 'Tokyo',
        city: 'tokyo',
        countryCode: 'JP',
        stock: 1,
        price: 9,
      ),
    ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Japan · Tokyo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty catalog says so', (tester) async {
    await pump(tester);
    expect(find.text('No native IPs are available right now.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the purchased tab lists owned IPs and copies credentials', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    api.userProxiesList = [
      {
        'id': 1,
        'host': '198.51.100.7',
        'port': 1080,
        'username': 'u',
        'password': 'p',
        'country': 'JP',
        'city': 'Tokyo',
        'type': 'socks5',
        'expired_at': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
        'auto_renew': true,
        'in_tunnel': true,
      },
      {'id': 2, 'host': '198.51.100.8', 'port': 1080, 'country': 'US'},
    ];
    await pump(tester);

    await tester.tap(find.text('Purchased'));
    await tester.pumpAndSettle();
    expect(find.text('198.51.100.7:1080'), findsOneWidget);
    expect(find.text('JP · Tokyo'), findsOneWidget);
    expect(find.text('In a tunnel'), findsOneWidget);
    expect(find.text('Auto-renew'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy credentials').first);
    await tester.pump();
    expect(copied, 'u:p@198.51.100.7:1080');

    await _sendFind(tester);
    await tester.enterText(find.byType(TextField), 'US');
    await tester.pumpAndSettle();
    expect(find.text('198.51.100.7:1080'), findsNothing);
    expect(find.text('198.51.100.8:1080'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('buying bundles a tunnel and shows the backend refusal', (
    tester,
  ) async {
    api.nativeInventory['ipproxy/inventory/native'] = [
      _offer(
        country: 'United States',
        cityName: 'Los Angeles',
        city: 'los-angeles',
        countryCode: 'US',
        stock: 2,
        price: 12,
      ),
    ];
    api.tunnelPrices = [
      {
        'id': 4,
        'name': 'Standard',
        'price': 6,
        'traffic': 500,
        'type': 'standard',
      },
    ];
    api.nativeBuyResponse = {
      'order_no': 'N1',
      'ids': [9],
      'tunnel_ids': [3],
    };
    await pump(tester);

    await tester.tap(find.text('United States · Los Angeles'));
    await tester.pumpAndSettle();
    expect(find.text('Tunnel plan'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.textContaining('500 GB'), findsOneWidget);
    expect(
      find.text(
        'Tunnels are configured automatically once the IPs are delivered.',
      ),
      findsOneWidget,
    );
    expect(find.text('¥18.00'), findsOneWidget);

    await tester.tap(find.text('1 month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 months'));
    await tester.pumpAndSettle();
    expect(find.text('¥42.00'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.byTooltip('Buy'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a quantity from 1 to 2.'), findsOneWidget);
    expect(api.nativePurchases, isEmpty);

    await tester.enterText(find.byType(TextFormField), '2');
    await tester.pumpAndSettle();
    expect(find.text('¥84.00'), findsOneWidget);

    api.nativeBuyFailure = IpingFailure.unavailable;
    api.nativeBuyMessage = '余额不足';
    await tester.tap(find.byTooltip('Buy'));
    await tester.pumpAndSettle();
    expect(find.text('余额不足'), findsOneWidget);
    expect(api.nativePurchases, hasLength(1));

    api.nativeBuyFailure = null;
    api.nativeBuyMessage = null;
    await tester.tap(find.byTooltip('Buy'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Purchase placed. The tunnels are configured once the IPs are delivered.',
      ),
      findsOneWidget,
    );
    final purchase = api.nativePurchases.last;
    expect(purchase.path, 'ipproxy/buy/native');
    expect(purchase.data, {
      'day': 90,
      'country_code': 'US',
      'country': 'United States',
      'city': 'los-angeles',
      'count': 2,
      'bandwidth': 0,
      'router_buy': false,
      'tunnel_price_id': 4,
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('line B says the tunnel is configured immediately', (
    tester,
  ) async {
    api.nativeInventory['ipproxy/inventory/native2'] = [
      _offer(
        country: 'Japan',
        cityName: 'Tokyo',
        city: 'tokyo',
        countryCode: 'JP',
        stock: 1,
        price: 9,
      ),
    ];
    api.tunnelPrices = [
      {
        'id': 4,
        'name': 'Standard',
        'price': 6,
        'traffic': 1,
        'type': 'standard',
      },
    ];
    api.nativeBuyResponse = {
      'ids': [1],
      'tunnel_ids': [2],
    };
    await pump(tester);
    await tester.tap(find.text('Japan · Tokyo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tunnels are configured as soon as the purchase completes.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Buy'));
    await tester.pumpAndSettle();
    expect(
      find.text('Purchase placed. The tunnels are already configured.'),
      findsOneWidget,
    );
    expect(api.nativePurchases.single.path, 'ipproxy/buy/native2');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'missing tunnel plans block purchase because a tunnel is required',
    (tester) async {
      api.tunnelPlansFailure = IpingFailure.unavailable;
      api.nativeInventory['ipproxy/inventory/native'] = [
        _offer(
          country: 'United States',
          cityName: 'Los Angeles',
          city: 'los-angeles',
          countryCode: 'US',
          stock: 1,
          price: 12,
        ),
      ];
      await pump(tester);
      expect(
        find.text(
          'Tunnel plans could not be loaded. You can still buy the IP on its own.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('United States · Los Angeles'));
      await tester.pumpAndSettle();
      expect(find.text('No tunnel plans are available.'), findsOneWidget);
      await tester.tap(find.byTooltip('Buy'));
      await tester.pumpAndSettle();
      expect(find.text('No tunnel plans are available.'), findsWidgets);
      expect(api.nativePurchases, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('continent and tag chips filter together', (tester) async {
    api.nativeInventory['ipproxy/inventory/native'] = [
      _offer(
        country: 'United States',
        cityName: 'Los Angeles',
        city: 'los-angeles',
        countryCode: 'US',
        stock: 2,
        price: 12,
        tags: const [
          {'key': 'residential', 'label': 'Residential', 'tone': 'residential'},
          {'key': 'live', 'label': 'Live', 'tone': 'live'},
        ],
      ),
    ];
    api.nativeInventory['ipproxy/inventory/native2'] = [
      _offer(
        country: 'Japan',
        cityName: 'Tokyo',
        city: 'tokyo',
        countryCode: 'JP',
        stock: 1,
        price: 9,
        tags: const [
          {'key': 'residential', 'label': 'Residential', 'tone': 'residential'},
        ],
      ),
    ];
    await pump(tester);

    expect(find.text('Regions · 2'), findsOneWidget);
    expect(find.text('North America'), findsOneWidget);
    expect(find.text('Asia'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('native-ip-filter-continent-NA')),
    );
    await tester.pumpAndSettle();
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.text('Japan · Tokyo'), findsNothing);
    expect(find.text('Regions · 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('native-ip-filter-continent-all')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Japan · Tokyo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('native-ip-filter-tag-live')));
    await tester.pumpAndSettle();
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.text('Japan · Tokyo'), findsNothing);
    expect(find.text('Clear (1)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('native-ip-filter-tag-residential')),
    );
    await tester.pumpAndSettle();
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.text('Clear (2)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('native-ip-filter-continent-AS')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No regions match these filters.'), findsOneWidget);
    expect(find.text('Regions · 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('native-ip-clear-tags')));
    await tester.pumpAndSettle();
    expect(find.text('Japan · Tokyo'), findsOneWidget);
    expect(find.text('United States · Los Angeles'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('native-ip-filter-continent-all')),
    );
    await tester.pumpAndSettle();
    expect(find.text('United States · Los Angeles'), findsOneWidget);
    expect(find.text('Japan · Tokyo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tag chips follow the store group and order', (tester) async {
    api.nativeInventory['ipproxy/inventory/native'] = [
      _offer(
        country: 'United States',
        cityName: 'Los Angeles',
        city: 'los-angeles',
        countryCode: 'US',
        stock: 2,
        price: 12,
        tags: const [
          {'key': 'legacy', 'label': 'Legacy'},
          {'key': 'segment', 'label': 'Segment', 'group': 'feature'},
          {'key': '300m', 'label': '300M', 'group': 'bandwidth', 'order': 3001},
          {'key': 'socks', 'label': 'SOCKS5', 'group': 'base'},
        ],
      ),
      _offer(
        country: 'United States',
        cityName: 'Seattle',
        city: 'seattle',
        countryCode: 'US',
        stock: 2,
        price: 12,
        tags: const [
          {'key': '20m', 'label': '20M', 'group': 'bandwidth', 'order': 201},
        ],
      ),
    ];
    await pump(tester);

    final keys = tester
        .widgetList<IpingPill>(find.byType(IpingPill))
        .map((pill) => (pill.key! as ValueKey<String>).value)
        .where((key) => key.startsWith('native-ip-filter-tag-'))
        .map((key) => key.substring('native-ip-filter-tag-'.length));
    expect(keys, ['socks', '20m', '300m', 'segment', 'legacy']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
