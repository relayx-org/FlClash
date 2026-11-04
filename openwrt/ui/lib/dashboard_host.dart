import 'dart:async';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/iping/probes.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'controller.dart';
import 'preferences.dart';

class RouterDashboardProbes extends ChangeNotifier
    implements IpingDashboardProbes {
  RouterDashboardProbes(this._probes)
    : outbound = RouterDashboardOutboundProbe(_probes),
      services = RouterDashboardServiceProbe(_probes),
      _revision = _probes.revision {
    _probes.addListener(_changed);
  }

  final IpingProbes _probes;
  int _revision;
  @override
  final RouterDashboardOutboundProbe outbound;
  @override
  final RouterDashboardServiceProbe services;

  @override
  Object? get error => _probes.error;

  void _changed() {
    if (_probes.revision == _revision) return;
    _revision = _probes.revision;
    notifyListeners();
  }

  @override
  void dispose() {
    _probes.removeListener(_changed);
    super.dispose();
  }
}

class RouterDashboardOutboundProbe implements IpingDashboardOutboundProbe {
  RouterDashboardOutboundProbe(this._probes);

  final IpingProbes _probes;

  @override
  RoutedProbeState<String, IpInfo> get state => _probes.outbound.state;
  @override
  void watch(String target) => _probes.outbound.watch(target);
  @override
  void unwatch(String target) => _probes.outbound.unwatch(target);
  @override
  IpQuality? qualityOf(String ip) => _probes.qualityOf(ip);
  @override
  bool isQualityLoading(String ip) => _probes.isQualityLoading(ip);
  @override
  void refreshOutbound() => _probes.refreshOutbound();
}

class RouterDashboardServiceProbe implements IpingDashboardServiceProbe {
  RouterDashboardServiceProbe(this._probes);

  final IpingProbes _probes;

  @override
  RoutedProbeState<ServiceTarget, ServiceCheck> get state =>
      _probes.services.state;
  @override
  void watch(ServiceTarget target) => _probes.services.watch(target);
  @override
  void unwatch(ServiceTarget target) => _probes.services.unwatch(target);
  @override
  void refresh(Iterable<ServiceTarget> targets) =>
      _probes.services.refresh(targets);
}

class RouterDashboardTelemetry extends ChangeNotifier {
  RouterDashboardTelemetry(this._controller)
    : _values = _valuesOf(_controller) {
    _controller.addListener(_changed);
  }

  final RouterController _controller;
  Object _values;

  static Object _valuesOf(RouterController controller) => (
    controller.traffic.revision,
    controller.telemetry.memory,
    controller.telemetry.connections,
  );

  void _changed() {
    final next = _valuesOf(_controller);
    if (next == _values) return;
    _values = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    super.dispose();
  }
}

class RouterNetworkTakeover implements IpingNetworkTakeover {
  RouterNetworkTakeover(this._controller, this._changed) {
    unawaited(_load());
  }

  final RouterController _controller;
  final VoidCallback _changed;
  bool _tun = false;
  bool _loaded = false;
  bool _disposed = false;

  @override
  bool get supportsSystemProxy => false;

  @override
  bool get supportsTun => true;

  @override
  bool get systemProxy => false;

  @override
  bool get tun => _tun;

  Future<void> _load() async {
    try {
      final settings = await _controller.backend.readSettings();
      if (_disposed) return;
      final tun = settings.flag('tun.enable');
      if (_loaded && tun == _tun) return;
      _tun = tun;
      _loaded = true;
      _changed();
    } catch (_) {
      // A settings read that fails leaves the last known switch state.
    }
  }

  @override
  Future<void> setTun(bool value) async {
    if (_disposed) return;
    final previous = _tun;
    _tun = value;
    _changed();
    try {
      await _controller.saveSettings({'tun.enable': value});
      if (_disposed) return;
      await _load();
    } catch (_) {
      if (!_disposed) {
        _tun = previous;
        _changed();
      }
      rethrow;
    }
  }

  @override
  Future<void> setSystemProxy(bool value) async {
    throw UnsupportedError('system proxy is not available on the router');
  }

  void dispose() {
    _disposed = true;
  }
}

class RouterDashboardHost extends ChangeNotifier implements IpingDashboardHost {
  RouterDashboardHost(
    this.controller, {
    required RouterPreferences preferences,
    required String Function(BuildContext context, Object error) describeError,
    required void Function(BuildContext context) openSubscription,
    required void Function(BuildContext context) openProxies,
    required void Function(BuildContext context) openConnections,
    required void Function(BuildContext context) openServices,
    required void Function(BuildContext context) openNetwork,
    required void Function(BuildContext context, String ip) openIpQuality,
    required void Function(List<String> ids) persistDashboardCards,
  }) : _preferences = preferences,
       _hideIp = preferences.hideIp,
       _serviceOrder = List.of(preferences.serviceOrder),
       _disabledServices = List.of(preferences.disabledServices),
       _dashboardCards = List.of(preferences.dashboardCards),
       _describeError = describeError,
       _openSubscription = openSubscription,
       _openProxies = openProxies,
       _openConnections = openConnections,
       _openServices = openServices,
       _openNetwork = openNetwork,
       _openIpQuality = openIpQuality,
       _persistDashboardCards = persistDashboardCards,
       probes = RouterDashboardProbes(controller.probes),
       telemetryUpdates = RouterDashboardTelemetry(controller),
       _status = _statusOf(controller) {
    _networkTakeover = RouterNetworkTakeover(controller, notifyListeners);
    controller.addListener(_controllerChanged);
  }

  final RouterController controller;
  IpingDashboardPreferences _preferences;
  bool _hideIp;
  List<String> _serviceOrder;
  List<String> _disabledServices;
  List<String> _dashboardCards;
  final String Function(BuildContext context, Object error) _describeError;
  final void Function(BuildContext context) _openSubscription;
  final void Function(BuildContext context) _openProxies;
  final void Function(BuildContext context) _openConnections;
  final void Function(BuildContext context) _openServices;
  final void Function(BuildContext context) _openNetwork;
  final void Function(BuildContext context, String ip) _openIpQuality;
  final void Function(List<String> ids) _persistDashboardCards;

  @override
  final RouterDashboardProbes probes;
  @override
  final RouterDashboardTelemetry telemetryUpdates;
  late final RouterNetworkTakeover _networkTakeover;
  Object _status;

  @override
  IpingNetworkTakeover get networkTakeover => _networkTakeover;

  static Object _statusOf(RouterController controller) => (
    controller.signedIn,
    controller.status.manualSubscription,
    controller.connected,
    controller.busy,
    controller.nodes,
    controller.email,
    controller.site,
    controller.status.updated,
    controller.error,
    controller.telemetry.mode,
    controller.revision,
    controller.siteConfig,
  );

  void _controllerChanged() {
    final next = _statusOf(controller);
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  void updatePreferences(RouterPreferences value) {
    _preferences = value;
    final serviceOrder = List.of(value.serviceOrder);
    final disabledServices = List.of(value.disabledServices);
    final dashboardCards = List.of(value.dashboardCards);
    if (value.hideIp == _hideIp &&
        listEquals(serviceOrder, _serviceOrder) &&
        listEquals(disabledServices, _disabledServices) &&
        listEquals(dashboardCards, _dashboardCards)) {
      return;
    }
    _hideIp = value.hideIp;
    _serviceOrder = serviceOrder;
    _disabledServices = disabledServices;
    _dashboardCards = dashboardCards;
    notifyListeners();
  }

  @override
  IpingDashboardPreferences get preferences => _preferences;

  /// The page builds its own cards; [dashboardCards] stores their arrangement.
  @override
  IpingDashboardEditor? get dashboardEditor => null;

  @override
  List<String> get dashboardCards => _dashboardCards;

  @override
  void saveDashboardCards(List<String> ids) {
    final next = List<String>.unmodifiable(ids);
    if (listEquals(next, _dashboardCards)) return;
    _dashboardCards = next;
    _persistDashboardCards(next);
    notifyListeners();
  }

  @override
  IpingBackend get backend => controller.backend;
  @override
  IpingBackendState get state => controller.status;
  @override
  bool get connected => controller.connected;
  @override
  bool get busy => controller.busy;
  @override
  bool get suspended => false;

  @override
  bool get visible => controller.visible;
  @override
  bool get hasSubscription => controller.status.hasSubscription;
  @override
  int get nodes => controller.nodes;
  @override
  DateTime? get updated => controller.status.updated;
  @override
  IpingTrafficSnapshot get traffic => controller.traffic;
  @override
  IpingTelemetry get telemetry => controller.telemetry;

  @override
  Future<IpingDashboardSnapshot> readDashboard() => controller.readDashboard();
  @override
  Future<void> synchronize() => controller.synchronize();
  @override
  Future<void> setConnected(bool value) async {
    await controller.setConnected(value);
  }

  @override
  Future<void> setMode(Mode mode) => controller.setMode(mode);
  @override
  Future<void> saveSettings(Map<String, Object?> changes) =>
      controller.saveSettings(changes);
  @override
  String errorText(BuildContext context, Object error) =>
      _describeError(context, error);
  @override
  void openSubscription(BuildContext context) => _openSubscription(context);
  @override
  void openProxies(BuildContext context) => _openProxies(context);
  @override
  void openConnections(BuildContext context) => _openConnections(context);
  @override
  void openServices(BuildContext context) => _openServices(context);
  @override
  void openNetwork(BuildContext context) => _openNetwork(context);
  @override
  void openIpQuality(BuildContext context, String ip) =>
      _openIpQuality(context, ip);

  @override
  void dispose() {
    _networkTakeover.dispose();
    controller.removeListener(_controllerChanged);
    probes.dispose();
    telemetryUpdates.dispose();
    super.dispose();
  }
}
