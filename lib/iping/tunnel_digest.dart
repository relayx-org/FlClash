import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'providers.dart';
import 'tunnel.dart';

const ipingExpiryNotice = Duration(days: 3);
const ipingRenewalWindow = Duration(days: 7);
const ipingTrafficNotice = 0.9;

class IpingTunnelDigest {
  const IpingTunnelDigest({
    this.expiring = const [],
    this.trafficLow = const [],
    this.renewingTunnels = const [],
    this.renewingProxies = const [],
  });

  /// Auto-renewing tunnels are left out: the store renews them itself.
  final List<IpingTunnel> expiring;

  final List<IpingTunnel> trafficLow;

  final List<IpingTunnel> renewingTunnels;

  final List<IpingUserProxy> renewingProxies;

  bool get needsAttention => expiring.isNotEmpty || trafficLow.isNotEmpty;

  int get renewalCount => renewingTunnels.length + renewingProxies.length;

  /// The list price; a reseller discount or a package makes the real charge
  /// lower, so this errs towards warning early.
  double get renewalCost =>
      renewingTunnels.fold(
        0.0,
        (sum, tunnel) => sum + (tunnel.planPrice?.toDouble() ?? 0),
      ) +
      renewingProxies.fold(0.0, (sum, proxy) => sum + proxy.price.toDouble());

  double? shortfall(double balance) {
    final missing = renewalCost - balance;
    return missing > 0.005 ? missing : null;
  }

  factory IpingTunnelDigest.of(
    List<IpingTunnel> tunnels, {
    List<IpingUserProxy> proxies = const [],
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    bool renewsSoon(DateTime? expiry) {
      if (expiry == null || !expiry.isAfter(current)) return false;
      return expiry.difference(current) <= ipingRenewalWindow;
    }

    final expiring = <IpingTunnel>[];
    final trafficLow = <IpingTunnel>[];
    final renewing = <IpingTunnel>[];
    for (final tunnel in tunnels) {
      final expiry = tunnel.expiredAt;
      if (tunnel.autoRenew) {
        if (renewsSoon(expiry) && tunnel.planPrice != null) {
          renewing.add(tunnel);
        }
      } else if (expiry != null &&
          expiry.difference(current) <= ipingExpiryNotice) {
        expiring.add(tunnel);
      }
      if (tunnel.totalTraffic > 0 &&
          tunnel.trafficCost >= tunnel.totalTraffic * ipingTrafficNotice) {
        trafficLow.add(tunnel);
      }
    }
    return IpingTunnelDigest(
      expiring: expiring,
      trafficLow: trafficLow,
      renewingTunnels: renewing,
      renewingProxies: [
        for (final proxy in proxies)
          if (proxy.autoRenew && proxy.price > 0 && renewsSoon(proxy.expiredAt))
            proxy,
      ],
    );
  }
}

extension TunnelDigestApi on IpingApi {
  static const _maxPages = 10;

  Future<List<IpingTunnel>> allTunnels() async {
    var page = await tunnels(const IpingTunnelQuery());
    for (var next = 2; page.hasMore && next <= _maxPages; next++) {
      final more = await tunnels(IpingTunnelQuery(page: next));
      if (more.items.isEmpty) break;
      page = page.append(more);
    }
    return page.items;
  }

  Future<IpingTunnelDigest> tunnelDigest() async {
    final (tunnels, proxies) = await (
      allTunnels(),
      userProxies().catchError((_) => const <IpingUserProxy>[]),
    ).wait;
    return IpingTunnelDigest.of(tunnels, proxies: proxies);
  }
}

final ipingUserProxiesProvider =
    FutureProvider.autoDispose<List<IpingUserProxy>>(
      (ref) => ref.watch(ipingAuthenticatedApiProvider).userProxies(),
      retry: (_, _) => null,
    );

final ipingTunnelDigestProvider =
    FutureProvider.autoDispose<IpingTunnelDigest?>((ref) async {
      final account = ref.watch(ipingSessionProvider.select((s) => s.account));
      if (account?.apiKey == null) return null;
      return ref.watch(ipingAuthenticatedApiProvider).tunnelDigest();
    }, retry: (_, _) => null);
