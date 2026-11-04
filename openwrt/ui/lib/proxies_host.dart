import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/proxies_host.dart';
import 'package:fl_clash/ui/proxy_style.dart';

import 'app.dart';
import 'controller.dart';

class RouterProxiesHost implements IpingProxiesHost {
  RouterProxiesHost(this.controller, this._app);

  final RouterController controller;
  final RouterAppState _app;

  @override
  IpingBackend get backend => controller.backend;
  @override
  bool get connected => controller.connected;
  @override
  bool get busy => controller.busy;
  @override
  int get revision => controller.revision;
  @override
  int get routeEpoch => controller.probes.outbound.route.coreEpoch;
  @override
  int get picksVersion => controller.probes.outbound.route.picksVersion;
  @override
  ProxyViewPreferences get preferences => _app.preferences.proxies;
  @override
  String get testUrl => _app.preferences.testUrl;
  @override
  bool get closeConnections => _app.preferences.closeConnections;

  @override
  void updatePreferences(ProxyViewPreferences value) =>
      _app.updatePreferences((settings) => settings.proxies = value);

  @override
  Future<void> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) => controller.selectProxy(group, name, closeConnections: closeConnections);
  @override
  Future<bool> testDelays(List<String> names, {required String url}) =>
      controller.testDelays(names, url: url);
  @override
  int? delayFor(String name, String url) => controller.delayFor(name, url);
  @override
  bool isTestingDelay(String name, String url) =>
      controller.isTestingDelay(name, url);
  @override
  bool isRunningDelay(String name, String url) =>
      controller.isRunningDelay(name, url);
  @override
  Future<void> testDelay(String name, {required String url}) =>
      controller.testDelay(name, url: url);

  @override
  void addListener(void Function() listener) =>
      controller.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      controller.removeListener(listener);
}
