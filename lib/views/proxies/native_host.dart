import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../enum/enum.dart';
import '../../iping/backend.dart';
import '../../iping/backend_native.dart';
import '../../iping/pages/proxies_page.dart';
import '../../iping/proxies_host.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'package:material_ui/material_ui.dart';

class NativeProxiesHost extends ChangeNotifier implements IpingProxiesHost {
  NativeProxiesHost(this.ref);

  final Ref ref;
  int _revision = 0;

  void refresh() {
    _revision++;
    notifyListeners();
  }

  @override
  IpingBackend get backend => ref.read(ipingBackendProvider);

  @override
  bool get connected => ref.read(coreStatusProvider) == CoreStatus.connected;

  @override
  bool get busy => false;

  @override
  int get revision => _revision;

  @override
  int get routeEpoch => 0;

  @override
  int get picksVersion => 0;

  @override
  ProxyViewPreferences get preferences {
    final style = ref.read(proxiesStyleSettingProvider);
    return ProxyViewPreferences(
      type: style.type,
      sort: style.sortType,
      layout: style.layout,
      icon: style.iconStyle,
      card: style.cardType,
      hideTimeout: style.hideTimeoutProxies,
    );
  }

  @override
  String get testUrl => ref.read(realTestUrlProvider());

  @override
  bool get closeConnections => ref.read(appSettingProvider).closeConnections;

  @override
  void updatePreferences(ProxyViewPreferences value) {
    ref.read(proxiesStyleSettingProvider.notifier).value = ProxiesStyleProps(
      type: value.type,
      sortType: value.sort,
      layout: value.layout,
      iconStyle: value.icon,
      cardType: value.card,
      hideTimeoutProxies: value.hideTimeout,
    );
  }

  @override
  Future<void> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) async {
    await backend.selectProxy(group, name, closeConnections: closeConnections);
  }

  Proxy? _proxy(String name) {
    for (final group in ref.read(groupsProvider)) {
      for (final proxy in group.all) {
        if (proxy.name == name) return proxy;
      }
    }
    return null;
  }

  @override
  Future<bool> testDelays(List<String> names, {required String url}) async {
    final proxies = [for (final name in names) ?_proxy(name)];
    if (proxies.isEmpty) return false;
    await ref.read(proxiesActionProvider.notifier).delayTest(proxies, url);
    return true;
  }

  @override
  int? delayFor(String name, String url) =>
      ref.read(delayDataSourceProvider)[name]?[url];

  @override
  bool isTestingDelay(String name, String url) =>
      ref.read(delayTestPhaseProvider(proxyName: name, testUrl: url)) != null;

  @override
  bool isRunningDelay(String name, String url) =>
      ref.read(delayTestPhaseProvider(proxyName: name, testUrl: url)) ==
      DelayTestPhase.running;

  @override
  Future<void> testDelay(String name, {required String url}) async {
    final proxy = _proxy(name);
    if (proxy == null) return;
    await ref.read(proxiesActionProvider.notifier).delayTest([proxy], url);
  }
}

class NativeProxiesRoute extends ConsumerWidget {
  const NativeProxiesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(_nativeProxiesHostProvider);
    ref.listen(groupsProvider, (_, _) => host.refresh());
    ref.listen(delayDataSourceProvider, (_, _) => host.refresh());
    ref.listen(coreStatusProvider, (_, _) => host.refresh());
    ref.listen(proxiesStyleSettingProvider, (_, _) => host.refresh());
    return IpingProxiesScope(host: host, child: const IpingProxiesPage());
  }
}

final _nativeProxiesHostProvider = Provider.autoDispose<NativeProxiesHost>((
  ref,
) {
  final host = NativeProxiesHost(ref);
  ref.onDispose(host.dispose);
  return host;
});
