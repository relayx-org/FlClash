import 'package:material_ui/material_ui.dart';

import 'backend.dart';

abstract interface class IpingDashboardPreferences {
  bool get hideIp;
  List<String> get serviceOrder;
  List<String> get disabledServices;
}

abstract interface class IpingDashboardOutboundProbe {
  void watch(String target);
  void unwatch(String target);
  RoutedProbeState<String, IpInfo> get state;
  IpQuality? qualityOf(String ip);
  bool isQualityLoading(String ip);
  void refreshOutbound();
}

abstract interface class IpingDashboardServiceProbe {
  void watch(ServiceTarget target);
  void unwatch(ServiceTarget target);
  RoutedProbeState<ServiceTarget, ServiceCheck> get state;
  void refresh(Iterable<ServiceTarget> targets);
}

abstract interface class IpingDashboardProbes implements Listenable {
  IpingDashboardOutboundProbe get outbound;
  IpingDashboardServiceProbe get services;
  Object? get error;
}

/// The shared dashboard host contract.
abstract interface class IpingDashboardHost implements Listenable {
  IpingBackend get backend;
  IpingBackendState get state;
  bool get connected;
  bool get busy;
  bool get visible;
  bool get suspended;
  bool get hasSubscription;
  int get nodes;
  DateTime? get updated;
  IpingTrafficSnapshot get traffic;
  IpingTelemetry get telemetry;
  Listenable get telemetryUpdates;
  IpingDashboardPreferences get preferences;
  IpingDashboardProbes get probes;
  Future<IpingDashboardSnapshot> readDashboard();
  Future<void> synchronize();
  Future<void> setConnected(bool value);
  Future<void> setMode(Mode mode);
  Future<void> saveSettings(Map<String, Object?> changes);
  String errorText(BuildContext context, Object error);
  void openSubscription(BuildContext context);
  void openProxies(BuildContext context);
  void openConnections(BuildContext context);
  void openServices(BuildContext context);
  void openNetwork(BuildContext context);
  void openIpQuality(BuildContext context, String ip);
}

class IpingDashboardScope extends InheritedNotifier<IpingDashboardHost> {
  const IpingDashboardScope({
    super.key,
    required IpingDashboardHost host,
    required super.child,
  }) : super(notifier: host);

  static IpingDashboardHost of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<IpingDashboardScope>()!
      .notifier!;

  static IpingDashboardHost read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<IpingDashboardScope>()!.notifier!;
}
