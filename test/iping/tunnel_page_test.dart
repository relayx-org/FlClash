import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/ui/context_menu.dart';
import 'package:fl_clash/ui/keyboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import 'fakes.dart';

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _sendFind(WidgetTester tester) async {
  final modifier = controlSingleActivator(LogicalKeyboardKey.keyF).meta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Future<void> _openEdit(WidgetTester tester, int id) async {
  final menu = tester.widget<ContextMenuRegion>(
    find
        .descendant(
          of: find.byKey(ValueKey('tunnel-row-$id')),
          matching: find.byType(ContextMenuRegion),
        )
        .first,
  );
  menu.menuItems!
      .firstWhere((item) => item.label == 'Edit Tunnel')
      .onPressed!();
  await _frames(tester);
}

Future<void> _choose(WidgetTester tester, String row, String option) async {
  await tester.tap(find.byKey(ValueKey(row)));
  await tester.pumpAndSettle();
  final item = find.text(option).last;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Map<String, Object?> _tunnel({
  required int id,
  required String name,
  required String status,
  required DateTime expiry,
  int port = 443,
  String? connectIp,
  List<String> nodeIps = const ['203.0.113.10'],
  String? conflict,
  bool autoRenew = true,
}) => {
  'id': id,
  'name': name,
  'tunnel_type': 'wss',
  'status': status,
  'listen_port': port,
  'expired_at': expiry.toIso8601String(),
  'auto_renew': autoRenew,
  'traffic': 0.5,
  'total_traffic': 100,
  'port_conflict_at': conflict,
  'in_node_group': {
    'name': 'US-Entry',
    'traffic_rate': 1.5,
    'connect_ip': connectIp,
    'nodes': [
      for (final ip in nodeIps) {'connect_ip': ip},
    ],
  },
  'out_node_group': {'name': 'Exit', 'traffic_rate': 1},
  'forward_addresses': {'10.1.0.8:80': 1},
  'tunnel_price': {
    'id': 3,
    'name': 'Standard',
    'price': 12,
    'tier': 1,
    'type': 'traffic',
  },
};

void main() {
  late FakeIpingApi api;
  late ProviderContainer container;
  final now = DateTime.now();

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

  Future<void> pump(WidgetTester tester, {int pageSize = 100}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          withStatusManager: true,
          child: IpingTunnelsPage(pageSize: pageSize),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void seed() {
    api.tunnels = [
      _tunnel(
        id: 1,
        name: 'Alpha',
        status: 'active',
        expiry: now.add(const Duration(days: 10)),
        conflict: now.subtract(const Duration(seconds: 15)).toIso8601String(),
      ),
      _tunnel(
        id: 2,
        name: 'Beta',
        status: 'inactive',
        expiry: now.add(const Duration(days: 4)),
        port: 80,
        connectIp: '198.51.100.2,2001:db8::2',
        nodeIps: const [],
      ),
      _tunnel(
        id: 3,
        name: 'Gamma',
        status: 'active',
        expiry: now.subtract(const Duration(days: 1)),
      ),
      _tunnel(
        id: 4,
        name: 'Delta',
        status: 'inactive',
        expiry: now.subtract(const Duration(days: 10)),
      ),
    ];
  }

  testWidgets('status chips and search follow the store query', (tester) async {
    seed();
    await pump(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Delta'), findsNothing);
    expect(find.text('Tunnels · 3'), findsOneWidget);
    expect(find.textContaining('Port in use'), findsOneWidget);
    expect(find.textContaining('198.51.100.2:80 +1'), findsOneWidget);
    expect(find.text('Expired'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-active')));
    await tester.pumpAndSettle();
    expect(api.tunnelQueries.last['status'], 'active');
    expect(api.tunnelQueries.last['is_expired'], 'false');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Gamma'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-expired')));
    await tester.pumpAndSettle();
    expect(api.tunnelQueries.last['is_expired'], 'true');
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Delta'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-all')));
    await tester.pumpAndSettle();
    await _sendFind(tester);
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    expect(api.tunnelQueries.last['name'], 'Beta');
    expect(find.byKey(const ValueKey('tunnel-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('tunnel-row-1')), findsNothing);
    expect(find.text('Tunnels · 1'), findsOneWidget);
  });

  testWidgets('an empty filter is distinct from a failed load', (tester) async {
    seed();
    api.tunnels.removeWhere((tunnel) => tunnel['name'] == 'Gamma');
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-expired')));
    await tester.pumpAndSettle();
    expect(find.text('No tunnels match these filters.'), findsOneWidget);

    api.tunnelsFailure = IpingFailure.session;
    await tester.tap(find.byKey(const ValueKey('tunnel-filter-all')));
    await tester.pumpAndSettle();
    expect(
      find.text('Your session is no longer valid. Please sign in again.'),
      findsOneWidget,
    );
    expect(find.text('No tunnels yet.'), findsNothing);
  });

  testWidgets('load more asks for the next page', (tester) async {
    api.tunnels = [
      _tunnel(
        id: 1,
        name: 'Alpha',
        status: 'active',
        expiry: now.add(const Duration(days: 1)),
      ),
      _tunnel(
        id: 2,
        name: 'Beta',
        status: 'active',
        expiry: now.add(const Duration(days: 1)),
      ),
    ];
    await pump(tester, pageSize: 1);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    expect(find.text('Tunnels · 2'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(api.tunnelQueries.last['page'], 2);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('detail copies the listen address and confirms renewal', (
    tester,
  ) async {
    seed();
    await pump(tester);

    await tester.tap(find.text('Alpha'));
    await _frames(tester);
    expect(find.text('Auto-renew'), findsOneWidget);
    expect(find.text('10.1.0.8:80'), findsOneWidget);
    expect(find.textContaining('Multiplier 1.5'), findsOneWidget);
    expect(find.text('0.5 GB / 100 GB'), findsWidgets);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) copied = arguments['text'] as String?;
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
    await tester.tap(find.text('203.0.113.10:443').last);
    await _frames(tester);
    expect(copied, '203.0.113.10:443');
    expect(find.text('Copied successfully'), findsOneWidget);

    final renew = find.byKey(const ValueKey('tunnel-renew'));
    await tester.ensureVisible(renew);
    await tester.tap(renew);
    await _frames(tester);
    expect(
      find.text('Renewing spends ¥12.00 from your balance.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await _frames(tester);
    expect(api.tunnelRenewals, isEmpty);

    await tester.ensureVisible(renew);
    await tester.tap(renew);
    await _frames(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Renew'));
    await _frames(tester);
    expect(api.tunnelRenewals, [1]);
    expect(find.text('Tunnel renewed.'), findsOneWidget);

    Future<Switch> toggle(String key) async {
      final finder = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(finder);
      return tester.widget<Switch>(finder);
    }

    expect((await toggle('tunnel-enabled')).value, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tunnel-enabled')),
        matching: find.byType(Switch),
      ),
    );
    await _frames(tester);
    expect(api.tunnelUpdates.last['status'], 'inactive');
    expect(api.tunnelUpdates.last['ids'], [1]);
    expect((await toggle('tunnel-enabled')).value, isFalse);

    expect((await toggle('tunnel-auto-renew')).value, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tunnel-auto-renew')),
        matching: find.byType(Switch),
      ),
    );
    await _frames(tester);
    expect(api.tunnelUpdates.last['auto_renew'], isFalse);
    expect((await toggle('tunnel-auto-renew')).value, isFalse);
  });

  testWidgets('editing tunnel updates name, address, and status', (
    tester,
  ) async {
    seed();
    await pump(tester);

    await _openEdit(tester, 1);

    expect(find.text('Edit Tunnel'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Alpha'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Alpha'),
      'Alpha Prime',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '10.1.0.8'),
      '192.168.1.1',
    );
    await tester.enterText(find.widgetWithText(TextField, '80'), '8080');
    await tester.pumpAndSettle();

    final saveButton = find.byTooltip('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Alpha Prime'), findsOneWidget);
    expect(find.text('Tunnel updated.'), findsOneWidget);
  });

  testWidgets('filter sheet filters by type and auto-renew and can be reset', (
    tester,
  ) async {
    seed();
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-more')));
    await _frames(tester);

    expect(find.text('Tunnel Type'), findsOneWidget);
    expect(find.text('Auto-renew'), findsWidgets);

    await _choose(tester, 'filter-sheet-type', 'Multiplexed encrypted TLS');
    await _choose(tester, 'filter-sheet-auto-renew', 'Disabled');
    await tester.tap(find.byTooltip('Confirm'));
    await tester.pumpAndSettle();

    expect(api.tunnelQueries.last['tunnel_type'], 'mtls');
    expect(api.tunnelQueries.last['auto_renew'], 'false');

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(api.tunnelQueries.last['tunnel_type'], isNull);
    expect(api.tunnelQueries.last['auto_renew'], isNull);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('edit page validates address and switches port', (tester) async {
    seed();
    await pump(tester);

    await _openEdit(tester, 1);

    await tester.enterText(find.widgetWithText(TextField, '80'), '99999');
    await tester.tap(find.byTooltip('Save'));
    await _frames(tester);
    expect(find.text('Port must be between 1 and 65535'), findsOneWidget);

    await tester.tap(find.text('Switch Port'));
    await _frames(tester);
    expect(find.text('Port switched successfully'), findsOneWidget);
    expect(find.text('444'), findsOneWidget);
  });

  testWidgets('edit page imports from clipboard and selects from native IPs', (
    tester,
  ) async {
    seed();
    api.userProxiesList = [
      {
        'id': 99,
        'host': '198.51.100.99',
        'port': 9090,
        'username': 'nativeuser',
        'password': 'nativepass',
        'country': 'US',
        'city': 'Miami',
        'remarks': 'Fast',
        'type': 'socks5',
      },
    ];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': 'socks5://clipuser:clippass@192.0.2.1:1080'};
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

    await pump(tester);
    await _openEdit(tester, 1);

    await tester.tap(find.byTooltip('Import from Clipboard'));
    await _frames(tester);

    expect(find.widgetWithText(TextField, '192.0.2.1'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'clipuser'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'clippass'), findsOneWidget);

    await tester.tap(find.byTooltip('Select from Native IPs'));
    await _frames(tester);

    expect(find.text('198.51.100.99:9090'), findsOneWidget);
    await tester.tap(find.text('198.51.100.99:9090'));
    await _frames(tester);

    expect(find.widgetWithText(TextField, '198.51.100.99'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9090'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'nativeuser'), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Tunnel updated.'), findsOneWidget);
  });

  testWidgets('locked forward address and dynamic IP pool controls', (
    tester,
  ) async {
    api.tunnels = [
      {
        ..._tunnel(
          id: 10,
          name: 'LockedTunnel',
          status: 'active',
          expiry: now.add(const Duration(days: 5)),
        ),
        'can_change_forward_address': false,
      },
      {
        ..._tunnel(
          id: 11,
          name: 'PoolTunnel',
          status: 'active',
          expiry: now.add(const Duration(days: 5)),
        ),
        'sk5_pool_mode': 'manual',
        'sk5_pool_country': 'US',
        'sk5_pool_interval_minutes': 30,
      },
    ];

    await pump(tester);

    await _openEdit(tester, 10);

    expect(
      find.text('Cannot change forward address while gifted IP is active'),
      findsOneWidget,
    );
    expect(find.text('10.1.0.8'), findsOneWidget);
    expect(find.widgetWithText(TextField, '10.1.0.8'), findsNothing);

    Navigator.of(tester.element(find.text('Edit Tunnel'))).pop();
    await tester.pumpAndSettle();

    await _openEdit(tester, 11);

    expect(
      find.textContaining('The exit comes from an address pool.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'US'), findsOneWidget);
    expect(find.widgetWithText(TextField, '30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tunnel-edit-switch-ip')));
    await _frames(tester);

    expect(api.switchedIpTunnels, [11]);
    expect(
      find.textContaining('Exit IP switched successfully'),
      findsOneWidget,
    );
  });

  testWidgets('filter sheet filters by IP type and port', (tester) async {
    seed();
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('tunnel-filter-more')));
    await _frames(tester);

    await _choose(tester, 'filter-sheet-ip-type', 'IPv4');
    await tester.enterText(
      find.byKey(const ValueKey('filter-sheet-port-input')),
      '80',
    );
    await tester.tap(find.byTooltip('Confirm'));
    await tester.pumpAndSettle();

    expect(api.tunnelQueries.last['ip_type'], 'v4');
    expect(api.tunnelQueries.last['listen_port'], 80);
    expect(find.text('IPv4'), findsOneWidget);
    expect(find.text('Listen Port: 80'), findsOneWidget);
  });

  testWidgets('batch selection, select all, deselect all, and exit mode', (
    tester,
  ) async {
    seed();
    await pump(tester);

    await tester.tap(find.byTooltip('Batch Operations'));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsNWidgets(2));

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Tunnels'), findsOneWidget);
  });

  testWidgets('batch renew tunnels', (tester) async {
    seed();
    await pump(tester);

    await tester.tap(find.byTooltip('Batch Operations'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batch Renew'));
    await _frames(tester);

    expect(find.text('Confirm Batch Renew'), findsOneWidget);
    expect(find.text('Alpha'), findsNWidgets(2));
    expect(find.text('Beta'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Confirm'));
    await tester.pumpAndSettle();

    expect(api.tunnelRenewals, containsAll(<int>[1, 2]));
    expect(find.textContaining('Batch renewed'), findsOneWidget);
  });

  testWidgets(
    'batch update status, auto-renew, generate names, and sequential IPs',
    (tester) async {
      seed();
      await pump(tester);

      await tester.tap(find.byTooltip('Batch Operations'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batch Settings'));
      await _frames(tester);

      await _choose(tester, 'batch-status', 'Enabled');
      await _choose(tester, 'batch-auto-renew', 'Enabled');
      await tester.enterText(
        find.byKey(const ValueKey('batch-name-prefix-input')),
        'US-Node-',
      );
      await tester.tap(find.byKey(const ValueKey('batch-name-generate-btn')));
      await tester.pump();

      final nameField = tester.widget<TextField>(
        find.byKey(const ValueKey('batch-update-name-input')),
      );
      expect(nameField.controller?.text, contains('US-Node-1'));

      await tester.enterText(
        find.byKey(const ValueKey('batch-update-ip-input')),
        '1.2.3.4:1080\n5.6.7.8:1080',
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Confirm'));
      await tester.pumpAndSettle();

      expect(api.tunnelUpdates.last['status'], 'active');
      expect(api.tunnelUpdates.last['auto_renew'], isTrue);
      expect(api.tunnelFills, isNotEmpty);
      final items =
          api.tunnelFills.last['items'] as List<Map<String, dynamic>>?;
      expect(items, isNotNull);
      expect(items!.first['id'], 1);
      expect(items.first['name'], 'US-Node-1');
      expect(items.first['forward_addresses'], {'1.2.3.4:1080': 1});
      expect(find.text('Batch updated successfully'), findsOneWidget);
    },
  );

  testWidgets('batch copy addresses', (tester) async {
    seed();
    await pump(tester);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) copied = arguments['text'] as String?;
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

    await tester.tap(find.byTooltip('Batch Operations'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy Addresses'));
    await _frames(tester);

    expect(copied, contains('203.0.113.10:443'));
    expect(copied, contains('198.51.100.2:80'));
    expect(find.text('Copied 3 listen addresses'), findsOneWidget);

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV'));
    await _frames(tester);
    expect(
      copied,
      startsWith('name,host,port,protocol,username,password,expires_at\n'),
    );
    expect(copied, contains('\nBeta #2,2001:db8::2,80,'));
    expect(copied!.split('\n'), hasLength(4));
  });
}
