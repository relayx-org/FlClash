import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/controller.dart';
import 'package:iping_openwrt/dashboard_host.dart';
import 'package:iping_openwrt/preferences.dart';

import 'fake_client.dart';

void main() {
  test('router takeover reads and persists the TUN switch', () async {
    final client = FakeRouterClient();
    client.settings['tun.enable'] = true;
    final controller = RouterController(client);
    addTearDown(controller.dispose);
    final host = RouterDashboardHost(
      controller,
      preferences: RouterPreferences(),
      describeError: (_, error) => error.toString(),
      openSubscription: (_) {},
      openProxies: (_) {},
      openConnections: (_) {},
      openServices: (_) {},
      openNetwork: (_) {},
      openIpQuality: (_, _) {},
      persistDashboardCards: (_) {},
    );
    addTearDown(host.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(host.networkTakeover.supportsSystemProxy, isFalse);
    expect(host.networkTakeover.supportsTun, isTrue);
    expect(host.networkTakeover.tun, isTrue);

    await host.networkTakeover.setTun(false);

    expect(client.settings['tun.enable'], isFalse);
    expect(host.networkTakeover.tun, isFalse);
  });
}
