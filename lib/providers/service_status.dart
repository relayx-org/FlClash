import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'config.dart';
import '../iping/backend_native.dart';
import '../iping/probes.dart';
import 'routed_probe.dart';

part 'generated/service_status.g.dart';

@Riverpod(keepAlive: true)
class ServiceStatus extends _$ServiceStatus
    with RoutedProbe<ServiceTarget, ServiceCheck> {
  @override
  RoutedProbeState<ServiceTarget, ServiceCheck> build() => buildProbe();

  @override
  bool isFailure(ServiceCheck value) => isServiceProbeFailure(value);

  @override
  Future<Map<ServiceTarget, ProbeAnswer<ServiceCheck>>> probe(
    ServiceTarget target,
    RouteState route,
  ) async {
    return ref.read(ipingBackendProvider).checkServices(
      route.proxied ? '' : directOutbound,
      [target],
    );
  }
}

@riverpod
List<ServiceTarget> serviceTargets(Ref ref) {
  final order = ref.watch(
    appSettingProvider.select((state) => SelectValue(state.serviceOrder)),
  );
  return orderServiceTargets(order.value);
}

@riverpod
List<ServiceTarget> enabledServiceTargets(Ref ref) {
  final targets = ref.watch(serviceTargetsProvider);
  final disabled = ref.watch(
    appSettingProvider.select((state) => SelectValue(state.disabledServices)),
  );
  return enabledServices(targets, disabled.value);
}
