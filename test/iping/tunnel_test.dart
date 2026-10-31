import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  Map<String, Object?> tunnel({
    Object? out = const {'name': 'Exit', 'traffic_rate': 1},
    Object? listenPort = 443,
    Object? connectIp,
    List<String> nodeIps = const ['203.0.113.10'],
    String? conflict,
    String expiredAt = '',
    Map<String, Object?> forwards = const {'10.1.0.8:80': 1},
    Object? pool,
  }) => {
    'id': 7,
    'name': 'LA-1',
    'tunnel_type': 'wss',
    'status': 'active',
    'listen_port': listenPort,
    'expired_at': expiredAt.isEmpty
        ? now.add(const Duration(days: 12)).toIso8601String()
        : expiredAt,
    'auto_renew': true,
    'traffic': 500 * 1024 * 1024,
    'total_traffic': 1024 * 1024 * 1024,
    'port_conflict_at': conflict,
    'in_node_group': {
      'name': 'US-Entry',
      'traffic_rate': 1.5,
      'connect_ip': connectIp,
      'nodes': [
        for (final ip in nodeIps) {'connect_ip': ip},
      ],
    },
    'out_node_group': out,
    'forward_addresses': forwards,
    'sk5_pool_mode': pool,
    'tunnel_price': {
      'id': 3,
      'name': 'Standard',
      'price': 12,
      'tier': 1,
      'type': 'traffic',
    },
  };

  test('parses a tunnel and keeps a missing exit', () {
    final parsed = IpingTunnel.tryParse(
      tunnel(out: null, forwards: const {'10.1.0.8:80': 2}),
    )!;

    expect(parsed.exit, isNull);
    expect(parsed.planName, 'Standard');
    expect(parsed.planPrice, 12);
    expect(parsed.autoRenew, isTrue);
    expect(parsed.forwardAddresses, {'10.1.0.8:80': 2});
    expect(parsed.listenAddresses, ['203.0.113.10:443']);
    expect(parsed.isExpired, isFalse);
    expect(parsed.poolExit, isFalse);
  });

  test('listen lines follow the store and a missing port waits', () {
    final fromNodes = IpingTunnel.tryParse(
      tunnel(
        listenPort: null,
        nodeIps: const ['203.0.113.10', '2001:db8::1,2001:db8::2'],
      ),
    )!;
    expect(fromNodes.listenAddresses, [
      '203.0.113.10:WAIT',
      '[2001:db8::1]:WAIT',
      '[2001:db8::2]:WAIT',
    ]);

    final fromGroup = IpingTunnel.tryParse(
      tunnel(connectIp: '198.51.100.2, 2001:db8::9'),
    )!;
    expect(fromGroup.listenAddresses, ['198.51.100.2:443', '2001:db8::9:443']);
  });

  test('expiry and a recent port conflict are visible', () {
    final recent = IpingTunnel.tryParse(
      tunnel(
        conflict: now.subtract(const Duration(seconds: 20)).toIso8601String(),
        expiredAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
      ),
    )!;
    expect(recent.isExpired, isTrue);
    expect(recent.portInUse, isTrue);

    final settled = IpingTunnel.tryParse(
      tunnel(
        conflict: now.subtract(const Duration(minutes: 2)).toIso8601String(),
      ),
    )!;
    expect(settled.portInUse, isFalse);
  });

  test('an address pool hides nothing the list needs and skips a bad row', () {
    final pooled = IpingTunnel.tryParse(
      tunnel(pool: 'rotate', forwards: const {}),
    )!;
    expect(pooled.poolExit, isTrue);
    expect(pooled.forwardAddresses, isEmpty);
    expect(IpingTunnel.tryParse({'id': 'nope'}), isNull);

    expect(
      () => IpingTunnelPage.fromJson({'data': const [], 'total': 'many'}),
      throwsFormatException,
    );
    expect(
      IpingTunnelPage.fromJson({
        'data': [
          tunnel(),
          {'id': null},
        ],
        'total': 2,
      }).items.single.id,
      7,
    );
  });

  test('a tunnel page that is not a list becomes unavailable', () async {
    final api = _ThrowingGet();
    await expectLater(
      api.tunnels(const IpingTunnelQuery()),
      throwsA(
        isA<IpingException>().having(
          (error) => error.failure,
          'failure',
          IpingFailure.unavailable,
        ),
      ),
    );
  });

  test('parses various proxy address formats from clipboard text', () {
    const raw = '''
socks5://alice:secret@192.168.1.1:1080
10.0.0.1:2080:bob:p@ss
charlie:pass123@172.16.0.1:3080
example.com:8080
invalid line
1.2.3.4:99999
''';
    final parsed = parseProxyAddresses(raw);
    expect(parsed.length, 4);

    expect(parsed[0].protocol, 'socks5');
    expect(parsed[0].host, '192.168.1.1');
    expect(parsed[0].port, 1080);
    expect(parsed[0].username, 'alice');
    expect(parsed[0].password, 'secret');

    expect(parsed[1].host, '10.0.0.1');
    expect(parsed[1].port, 2080);
    expect(parsed[1].username, 'bob');
    expect(parsed[1].password, 'p@ss');

    expect(parsed[2].host, '172.16.0.1');
    expect(parsed[2].port, 3080);
    expect(parsed[2].username, 'charlie');
    expect(parsed[2].password, 'pass123');

    expect(parsed[3].host, 'example.com');
    expect(parsed[3].port, 8080);
    expect(parsed[3].username, isEmpty);
    expect(parsed[3].password, isEmpty);
  });

  test('parses user proxy and tunnel credentials metadata', () {
    final proxy = IpingUserProxy.tryParse({
      'id': 10,
      'host': '1.2.3.4',
      'port': 1080,
      'username': 'u1',
      'password': 'p1',
      'country': 'US',
      'city': 'San Jose',
      'remarks': 'Fast',
      'type': 'socks5',
    });
    expect(proxy, isNotNull);
    expect(proxy!.id, 10);
    expect(proxy.host, '1.2.3.4');
    expect(proxy.port, 1080);
    expect(proxy.country, 'US');

    final parsedTunnel = IpingTunnel.tryParse({
      ...tunnel(),
      'forward_addresses_protocol': {
        'type': 'socks5',
        'username': 'fuser',
        'password': 'fpass',
      },
      'can_change_forward_address': false,
      'sk5_pool_country': 'HK',
      'sk5_pool_interval_minutes': 15,
      'ip_type': 'v6',
    });
    expect(parsedTunnel, isNotNull);
    expect(parsedTunnel!.forwardUsername, 'fuser');
    expect(parsedTunnel.forwardPassword, 'fpass');
    expect(parsedTunnel.canChangeForwardAddress, isFalse);
    expect(parsedTunnel.poolCountry, 'HK');
    expect(parsedTunnel.poolIntervalMinutes, 15);
    expect(parsedTunnel.ipType, 'v6');

    const query = IpingTunnelQuery(
      ipType: 'v6',
      listenPort: 1234,
      tunnelType: 'relayx',
    );
    final params = query.toParameters();
    expect(params['ip_type'], 'v6');
    expect(params['listen_port'], 1234);
    expect(params['tunnel_type'], 'relayx');
  });
}

class _ThrowingGet extends IpingApi {
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return {'data': const <Object?>[], 'total': 'many'} as T;
  }
}
