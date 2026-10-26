import 'dart:async';

import 'backend_data.dart';
import 'backend_settings.dart';
import 'backend_telemetry.dart';
import 'backend_resources.dart';
import 'site_config.dart';
import 'profile_resources.dart';
import 'backend_dashboard.dart';
import 'user_info.dart';
import '../common/routed_probe.dart';
import '../common/service_probe_data.dart';
import '../models/ip_quality.dart';

export 'backend_data.dart';
export 'backend_settings.dart';
export 'backend_telemetry.dart';
export 'backend_resources.dart';
export 'profile_resources.dart';
export 'backend_dashboard.dart';
export 'user_info.dart';
export '../common/routed_probe.dart';
export '../common/service_probe_data.dart';
export '../models/ip_quality.dart';
export '../enum/ip_quality.dart';

enum IpingBackendCapability { systemProxy, vpn, tun, tray, routerNetwork }

class IpingBackendState {
  const IpingBackendState({
    this.initialized = false,
    this.signedIn = false,
    this.connected = false,
    this.busy = false,
    this.nodes = 0,
    this.email = '',
    this.site = 'https://iping.my',
    this.updated,
  });

  final bool initialized;
  final bool signedIn;
  final bool connected;
  final bool busy;
  final int nodes;
  final String email;
  final String site;
  final DateTime? updated;
}

abstract interface class IpingBackend {
  Set<IpingBackendCapability> get capabilities;
  Set<IpingResourceKind> get resourceKinds;
  IpingResourceStore<Filter> get filters;
  IpingResourceStore<IpingCustomProxy> get customProxies;
  IpingResourceStore<IpingRuleProvider> get ruleProviders;
  IpingResourceStore<IpingAddedRule> get addedRules;
  IpingResourceStore<IpingScript> get scripts;
  Future<IpingProfileResources> readProfileResources();
  Future<void> updateProfileResources(IpingProfileResources value);

  Future<IpingBackendState> readState();
  Future<IpingSiteConfig> readSiteConfig();
  Future<IpingUserInfo?> readAccount();
  Future<IpingDashboardSnapshot> readDashboard();
  Future<RouteState> readProbeRoute();
  Future<IpQuality> readIpQuality(String ip);
  Future<ProbeAnswer<IpInfo>> lookupOutboundIp(String proxyName);
  Future<Map<ServiceTarget, ProbeAnswer<ServiceCheck>>> checkServices(
    String proxyName,
    List<ServiceTarget> targets,
  );
  Future<void> signIn({bool register = false});
  void cancelSignIn();
  Future<void> synchronize();
  Future<bool> setConnected(bool connected);
  Future<void> setMode(Mode mode);
  Future<IpingTelemetry> readTelemetry();
  Future<void> signOut();

  Future<IpingProxyPage> readProxies([
    IpingProxyQuery query = const IpingProxyQuery(),
  ]);
  Future<bool> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  });
  Future<Delay?> testDelay(String name, {required String url});
  Future<IpingConnectionPage> readConnections([
    IpingConnectionQuery query = const IpingConnectionQuery(),
  ]);
  Future<int> readConnectionCount();
  Future<void> closeConnection(String id);
  Future<void> closeConnections();
  FutureOr<IpingLogSnapshot> readLogs();

  FutureOr<IpingSettings> readSettings();
  // Null removes a supported DNS/TUN override; false and empty lists remain values.
  Future<void> updateSettings(Map<String, Object?> changes);
}
