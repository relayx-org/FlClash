import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/site_config.dart';

import 'backend.dart';
import 'client.dart';

Map<String, dynamic> objectOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class RouterController extends ChangeNotifier {
  RouterController(this.client, {IpingBackend? backend})
    : _backend = backend ?? RouterBackend(client);

  final RouterClient client;
  final IpingBackend _backend;
  IpingBackend get backend => _backend;
  final testing = <String>{};
  final delays = <String, int>{};
  IpingBackendState status = const IpingBackendState();
  IpingTelemetry telemetry = const IpingTelemetry();
  IpingTrafficSnapshot get traffic => telemetry.traffic;
  Map<String, dynamic> account = {};
  IpingSiteConfig siteConfig = const IpingSiteConfig();
  Timer? _timer;
  int revision = 0;
  bool initialized = false;
  bool pending = false;
  bool authorizing = false;
  bool _refreshing = false;
  bool _disposed = false;
  String? error;

  bool get signedIn => status.signedIn;
  bool get connected => status.connected;
  bool get busy => pending || authorizing || status.busy;
  int get nodes => status.nodes;
  String get email => status.email;
  String get site => status.site;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await refresh();
    if (_disposed) return;
    initialized = true;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    if (signedIn) unawaited(refreshAccount());
    unawaited(_loadSiteConfig());
    _changed();
  }

  Future<void> _loadSiteConfig() async {
    try {
      final config = await backend.readSiteConfig();
      if (_disposed) return;
      siteConfig = config;
      _changed();
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      final nextStatus = await backend.readState();
      if (_disposed) return;
      status = nextStatus;
      if (signedIn && !status.busy) {
        final next = await backend.readTelemetry();
        if (_disposed) return;
        telemetry = next;
        if (connected) revision++;
      } else if (!connected || !signedIn) {
        telemetry = IpingTelemetry(mode: signedIn ? telemetry.mode : Mode.rule);
      }
    } catch (exception) {
      error = exception.toString();
    } finally {
      _refreshing = false;
      _changed();
    }
  }

  Future<void> refreshAccount() async {
    try {
      account = objectOf(await client.call('account'));
    } catch (exception) {
      error = exception.toString();
    }
    _changed();
  }

  Future<void> signIn({bool register = false}) async {
    if (busy) return;
    authorizing = true;
    error = null;
    _changed();
    try {
      await backend.signIn(register: register);
      if (_disposed) return;
      await refresh();
      if (signedIn) {
        await refreshAccount();
      }
    } catch (exception) {
      error = exception.toString();
      await refresh();
    } finally {
      authorizing = false;
      _changed();
    }
  }

  void cancelSignIn() => backend.cancelSignIn();

  Future<void> setConnected(bool connected) => _operate(() async {
    await backend.setConnected(connected);
  });

  Future<void> synchronize() => _operate(backend.synchronize);

  Future<void> signOut() => _operate(backend.signOut);

  Future<void> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) => _operate(() async {
    await backend.selectProxy(group, name, closeConnections: closeConnections);
  });

  Future<void> closeConnection(String id) => _operate(
    () => id.isEmpty ? backend.closeConnections() : backend.closeConnection(id),
  );

  Future<void> setMode(Mode mode) => _operate(() => backend.setMode(mode));

  Future<void> _operate(Future<void> Function() operation) async {
    if (busy || _disposed) return;
    pending = true;
    error = null;
    _changed();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
    } finally {
      pending = false;
      await refresh();
      if (!signedIn) account = {};
      _changed();
    }
  }

  Future<void> saveSettings(Map<String, Object?> changes) async {
    if (busy) throw const RouterException('busy');
    pending = true;
    error = null;
    _changed();
    try {
      await backend.updateSettings(changes);
    } finally {
      pending = false;
      await refresh();
      _changed();
    }
  }

  Future<int?> testDelay(String name, {String? url}) async {
    if (testing.contains(name)) return null;
    testing.add(name);
    _changed();
    try {
      final result = await backend.testDelay(
        name,
        url: url ?? 'https://www.gstatic.com/generate_204',
      );
      final delay = result?.value;
      if (delay != null) delays[name] = delay;
      return delay;
    } catch (exception) {
      error = exception.toString();
      return null;
    } finally {
      testing.remove(name);
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    backend.cancelSignIn();
    super.dispose();
  }
}
