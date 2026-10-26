import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'service_probe_data.dart';
export 'service_probe_data.dart';

const directOutbound = 'DIRECT';
const routedOutbound = '';

/// An empty [proxyName] lets the Core route by its rules; an empty [targets]
/// checks every service.
Future<Map<ServiceTarget, ServiceCheck>> checkServices(
  CoreController core, {
  String proxyName = '',
  List<ServiceTarget> targets = const [],
  Duration timeout = probeTimeoutDuration,
}) async {
  final items = await core.serviceCheck(
    ServiceCheckParams(
      proxyName: proxyName,
      names: targets.map((target) => target.id).toList(),
      timeout: timeout.inMilliseconds,
    ),
  );
  return {
    for (final item in items)
      ?ServiceTarget.byId(item.name): serviceCheckOf(item),
  };
}

/// Raw so the route stamp survives; [parseOutboundIp] reads the address.
Future<OutboundIpResult?> lookupOutboundIp(
  CoreController core,
  String proxyName, {
  Duration timeout = outboundIpTimeoutDuration,
}) {
  return core.outboundIp(
    OutboundIpParams(
      proxyName: proxyName,
      urls: ipInfoSources.keys.toList(),
      timeout: timeout.inMilliseconds,
    ),
  );
}

IpInfo? parseOutboundIp(OutboundIpResult? result) {
  return parseOutboundIpBody(
    url: result?.url,
    body: result?.body,
    error: result?.error,
  );
}

ServiceCheck serviceCheckOf(ServiceCheckItem item) {
  return ServiceCheck(
    ServiceProbeStatus.byId(item.status),
    delay: item.delay > 0 ? item.delay : null,
    chains: item.chains,
    region: item.region.isEmpty ? null : item.region,
    checkedAt: item.checkedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(item.checkedAt)
        : null,
    coreEpoch: item.coreEpoch,
    picksVersion: item.picksVersion,
  );
}
