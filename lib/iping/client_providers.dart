import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enum/page_label.dart';
import 'api.dart';
import 'native_ip.dart';
import 'tunnel.dart';
import 'user_info.dart';

/// The account API used by the shared store pages. The native app and the
/// router Web UI provide their own implementation.
final ipingClientProvider = Provider<IpingApi>(
  (ref) => throw StateError('The iPing client is not configured'),
);

final ipingNativeIpInventoryProvider =
    FutureProvider.autoDispose<List<NativeIpOffer>>(
      (ref) => ref.watch(ipingClientProvider).nativeIpInventory(),
      retry: (_, _) => null,
    );

final ipingTunnelPlansProvider = FutureProvider.autoDispose<List<TunnelPlan>>(
  (ref) => ref.watch(ipingClientProvider).tunnelPlans(),
  retry: (_, _) => null,
);

final ipingTunnelPlanOptionsProvider =
    FutureProvider.autoDispose<List<IpingTunnelPlanOption>>(
      (ref) => ref.watch(ipingClientProvider).tunnelPlanOptions(),
      retry: (_, _) => null,
    );

final ipingUserProxiesProvider =
    FutureProvider.autoDispose<List<IpingUserProxy>>(
      (ref) => ref.watch(ipingClientProvider).userProxies(),
      retry: (_, _) => null,
    );

final ipingUserInfoProvider = FutureProvider.autoDispose<IpingUserInfo?>(
  (ref) async => ref.watch(ipingClientProvider).userInfo(),
  retry: (_, _) => null,
);

typedef IpingNavigate = void Function(PageLabel label);

final ipingNavigateProvider = Provider<IpingNavigate>((ref) => (_) {});
