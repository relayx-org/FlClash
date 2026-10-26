export '../common/routed_probe.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/routed_probe.dart';
import 'package:fl_clash/core/method.dart';
import 'package:riverpod/riverpod.dart';

import 'app.dart';
import 'route_state.dart';

mixin RoutedProbe<K, V>
    on AnyNotifier<RoutedProbeState<K, V>, RoutedProbeState<K, V>> {
  RoutedProbeController<K, V>? _controller;

  Future<Map<K, ProbeAnswer<V>>> probe(K target, RouteState route);
  bool isFailure(V value) => false;

  RoutedProbeState<K, V> buildProbe() {
    final controller = _controller = RoutedProbeController<K, V>(
      probe: probe,
      isFailure: isFailure,
      route: ref.read(routeTrackerProvider),
      visible: ref.read(appVisibleProvider),
      onAttach: () => ref.read(routeTrackerProvider.notifier).attach(),
      onDetach: () => ref.read(routeTrackerProvider.notifier).detach(),
      onResync: () => ref.read(routeTrackerProvider.notifier).resync(),
      onError: (error) => commonPrint.log(
        'probe failed: $error',
        logLevel: coreFailureLogLevel(error),
      ),
    );
    controller.addListener(() {
      if (ref.mounted) state = controller.state;
    });
    ref.onDispose(controller.dispose);
    ref.listen(
      routeTrackerProvider,
      (_, next) => controller.receiveRoute(next),
    );
    ref.listen(appVisibleProvider, (_, next) => controller.setVisible(next));
    return controller.state;
  }

  void watch(K target) => _controller?.watch(target);
  void unwatch(K target) => _controller?.unwatch(target);
  void refresh(Iterable<K> targets) => _controller?.refresh(targets);
}
