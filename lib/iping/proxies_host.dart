import 'package:material_ui/material_ui.dart';

import '../ui/proxy_style.dart';
import 'backend.dart';

/// Everything the shared proxy page needs from its host application.
abstract interface class IpingProxiesHost implements Listenable {
  IpingBackend get backend;
  bool get connected;
  bool get busy;
  int get revision;
  int get routeEpoch;
  int get picksVersion;
  ProxyViewPreferences get preferences;
  String get testUrl;
  bool get closeConnections;
  void updatePreferences(ProxyViewPreferences value);
  Future<void> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  });
  Future<bool> testDelays(List<String> names, {required String url});
  int? delayFor(String name, String url);
  bool isTestingDelay(String name, String url);
  bool isRunningDelay(String name, String url);
  Future<void> testDelay(String name, {required String url});
}

class IpingProxiesScope extends InheritedNotifier<IpingProxiesHost> {
  const IpingProxiesScope({
    super.key,
    required IpingProxiesHost host,
    required super.child,
  }) : super(notifier: host);

  static IpingProxiesHost of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<IpingProxiesScope>()!
      .notifier!;

  static IpingProxiesHost read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<IpingProxiesScope>()!.notifier!;
}
