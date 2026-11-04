import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import 'backend.dart';

class IpingDashboardCard {
  const IpingDashboardCard({
    required this.id,
    required this.label,
    required this.builder,
    this.description,
    this.glyph,
    this.removable = true,
    this.desktop = const [],
  });

  final String id;
  final String Function(BuildContext context) label;
  final String? Function(BuildContext context)? description;
  final WidgetBuilder builder;
  final Glyph? glyph;
  final bool removable;

  final List<IpingDashboardDesktopCard> desktop;

  @override
  bool operator ==(Object other) =>
      other is IpingDashboardCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class IpingDashboardDesktopCard {
  const IpingDashboardDesktopCard({
    required this.area,
    required this.builder,
    this.span = 1,
  });

  final IpingDashboardDesktopArea area;
  final WidgetBuilder builder;

  final int span;
}

enum IpingDashboardDesktopArea {
  outbound,
  upload,
  download,
  mode,
  control,
  middle,
  summary,
  table,
}

abstract interface class IpingDashboardEditor {
  List<IpingDashboardCard> get cards;

  List<IpingDashboardCard> get available;

  List<IpingDashboardCard> get desktopCards;

  void save(List<String> ids);

  void reset();
}

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

  /// Cards the host builds itself; null builds the page's own card set.
  IpingDashboardEditor? get dashboardEditor;

  /// The saved order and visibility of the page's own cards, or null when the
  /// host leaves that set fixed and uneditable.
  List<String>? get dashboardCards;

  void saveDashboardCards(List<String> ids);

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
