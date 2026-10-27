import 'package:fl_clash/iping/probes.dart';

import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/controller.dart';

import 'backend.dart';
import 'client.dart';

Map<String, dynamic> objectOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class RouterController extends IpingController {
  RouterController(this.client, {IpingBackend? backend})
    : super(
        backend ?? RouterBackend(client),
        isUnavailableError: (error) =>
            error is RouterException &&
            error.message == 'controller_unavailable',
      ) {
    probes = IpingProbes(this.backend)..addListener(notifyListeners);
  }

  final RouterClient client;
  late final IpingProbes probes;

  @override
  void setVisible(bool value) {
    probes.setVisible(value);
    super.setVisible(value);
  }

  @override
  Future<void> refresh({bool force = false}) async {
    await super.refresh(force: force);
    if (_closed) return;
    if (status.hasSubscription) {
      await probes.refreshRoute();
    } else {
      probes.reset();
    }
  }

  bool _closed = false;
  @override
  void dispose() {
    _closed = true;
    probes.dispose();
    super.dispose();
  }

  @override
  Future<void> initialize({Duration? pollInterval}) => super.initialize(
    pollInterval: pollInterval ?? const Duration(seconds: 3),
  );
}
