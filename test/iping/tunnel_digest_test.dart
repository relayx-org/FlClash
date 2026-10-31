import 'dart:io';

import 'package:fl_clash/iping/tunnel.dart';
import 'package:fl_clash/iping/tunnel_digest.dart';
import 'package:fl_clash/iping/tunnel_export.dart';
import 'package:fl_clash/iping/tunnel_probe.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 31, 12);

IpingTunnel _tunnel(
  int id, {
  Duration expiresIn = const Duration(days: 30),
  bool autoRenew = false,
  num trafficCost = 0,
  num totalTraffic = 0,
  num? planPrice = 12,
  String name = 'Tokyo',
  int? listenPort = 443,
  List<String> nodes = const ['203.0.113.10'],
  String? listenProtocol,
  String? listenUsername,
  String? listenPassword,
  String? forwardUsername,
  String? forwardPassword,
}) => IpingTunnel(
  id: id,
  name: name,
  type: 'tcp',
  status: 'active',
  listenPort: listenPort,
  expiredAt: _now.add(expiresIn),
  autoRenew: autoRenew,
  trafficCost: trafficCost,
  totalTraffic: totalTraffic,
  planPrice: planPrice,
  entrance: IpingTunnelEndpoint(name: 'Entry', nodeAddresses: nodes),
  listenProtocol: listenProtocol,
  listenUsername: listenUsername,
  listenPassword: listenPassword,
  forwardUsername: forwardUsername,
  forwardPassword: forwardPassword,
);

void main() {
  group('digest', () {
    test('reminds of expiring and nearly used tunnels only', () {
      final digest = IpingTunnelDigest.of([
        _tunnel(1, expiresIn: const Duration(days: 2)),
        _tunnel(2, expiresIn: const Duration(days: -1)),
        _tunnel(3, expiresIn: const Duration(days: 2), autoRenew: true),
        _tunnel(4, trafficCost: 9.5, totalTraffic: 10),
        _tunnel(5, trafficCost: 5, totalTraffic: 10),
        _tunnel(6, trafficCost: 50),
      ], now: _now);
      expect(digest.expiring.map((t) => t.id), [1, 2]);
      expect(digest.trafficLow.map((t) => t.id), [4]);
      expect(digest.needsAttention, isTrue);
    });

    test('sums the renewals due within a week against the balance', () {
      final digest = IpingTunnelDigest.of(
        [
          _tunnel(1, expiresIn: const Duration(days: 3), autoRenew: true),
          _tunnel(2, expiresIn: const Duration(days: 9), autoRenew: true),
          _tunnel(3, expiresIn: const Duration(days: -1), autoRenew: true),
        ],
        proxies: [
          IpingUserProxy(
            id: 1,
            host: '198.51.100.1',
            port: 1080,
            price: 30,
            autoRenew: true,
            expiredAt: _now.add(const Duration(days: 5)),
          ),
          IpingUserProxy(
            id: 2,
            host: '198.51.100.2',
            port: 1080,
            price: 30,
            expiredAt: _now.add(const Duration(days: 5)),
          ),
        ],
        now: _now,
      );
      expect(digest.renewalCount, 2);
      expect(digest.renewalCost, 42);
      expect(digest.shortfall(40), closeTo(2, 0.001));
      expect(digest.shortfall(42), isNull);
      expect(digest.needsAttention, isFalse);
    });
  });

  group('export', () {
    final tunnels = [
      _tunnel(
        1,
        nodes: ['203.0.113.10', '2001:db8::1'],
        listenProtocol: 'socks5',
        listenUsername: 'u',
        listenPassword: 'p,"q',
      ),
      _tunnel(2, name: 'Plain'),
      _tunnel(3, listenPort: null),
    ];

    test('lines put the credentials after the address', () {
      final export = exportTunnels(tunnels, IpingTunnelExportFormat.lines);
      expect(export.count, 3);
      expect(
        export.text,
        '203.0.113.10:443:u:p,"q\n'
        '[2001:db8::1]:443:u:p,"q\n'
        '203.0.113.10:443',
      );
    });

    test('clash keeps only a typed proxy and names each uniquely', () {
      final export = exportTunnels([
        ...tunnels,
        _tunnel(4, name: 'Tokyo #1', listenProtocol: 'http'),
      ], IpingTunnelExportFormat.clash);
      expect(export.count, 3);
      expect(export.text, contains('  - name: "Tokyo #1"\n    type: socks5'));
      expect(export.text, contains('  - name: "Tokyo #1 (2)"\n    type: http'));
      expect(export.text, contains('    server: "2001:db8::1"'));
      expect(export.text, contains('    password: "p,\\"q"'));
      expect(export.text, isNot(contains('Plain')));
    });

    test('csv quotes a field with a comma or a quote', () {
      final lines = exportTunnels(
        tunnels,
        IpingTunnelExportFormat.csv,
      ).text.split('\n');
      expect(
        lines.first,
        'name,host,port,protocol,username,password,expires_at',
      );
      expect(
        lines[1],
        'Tokyo #1,203.0.113.10,443,socks5,u,"p,""q",'
        '${_now.add(const Duration(days: 30)).toIso8601String()}',
      );
      expect(lines, hasLength(4));
    });
  });

  test('a probe times the connect and reads a failure as -1', () async {
    final hosts = <String>[];
    Future<Socket> refuse(String host, int port, {Duration? timeout}) {
      hosts.add('$host $port');
      throw const SocketException('refused');
    }

    expect(await probeListenAddress('[2001:db8::1]:443', connect: refuse), -1);
    expect(await probeListenAddress('203.0.113.10:WAIT', connect: refuse), -1);
    expect(hosts, ['2001:db8::1 443']);

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) => socket.destroy());
    expect(
      await probeListenAddress('127.0.0.1:${server.port}'),
      greaterThanOrEqualTo(0),
    );
  });
}
