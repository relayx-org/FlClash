import 'package:fl_clash/common/service_probe.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../iping/backend_native.dart';
import '../iping/probes.dart';
import 'routed_probe.dart';

part 'generated/outbound_ip.g.dart';

/// Keyed by the outbound a lookup pins: a node name, `DIRECT`, or
/// [routedOutbound] for whatever the rules pick right now.
@Riverpod(keepAlive: true)
class OutboundIpProbe extends _$OutboundIpProbe
    with RoutedProbe<String, IpInfo> {
  @override
  RoutedProbeState<String, IpInfo> build() => buildProbe();

  @override
  Future<Map<String, ProbeAnswer<IpInfo>>> probe(
    String target,
    RouteState route,
  ) async {
    return outboundProbeAnswers(
      target,
      route,
      ref.read(ipingBackendProvider).lookupOutboundIp,
    );
  }
}
