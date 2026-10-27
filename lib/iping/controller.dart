import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'delay_scheduler.dart';
import 'site_config.dart';

class IpingBusyException implements Exception {
  const IpingBusyException();
  @override
  String toString() => 'busy';
}

class IpingController extends ChangeNotifier {
  IpingController(
    this.backend, {
    this.refreshDetails = true,
    this.throwOnError = false,
    this.cancelSignInOnDispose = true,
    this.isUnavailableError,
    int delayConcurrency = 4,
  }) : _delayConcurrency = delayConcurrency;

  final IpingBackend backend;
  final bool refreshDetails;
  final bool throwOnError;
  final bool cancelSignInOnDispose;
  final int _delayConcurrency;
  final bool Function(Object error)? isUnavailableError;
  final _delayRunning = <String>{};
  final _delayNames = <String, int>{};
  late final IpingDelayScheduler _delayTasks = IpingDelayScheduler(
    concurrency: _delayConcurrency,
    test: (target) => backend.testDelay(target.proxyName, url: target.testUrl),
    onAcquire: (_, running) {
      _delayRunning.addAll(running);
      _delaysChanged();
    },
    onStart: (key) {
      _delayRunning.add(key);
      _delaysChanged();
    },
    onFinish: (key) {
      _delayRunning.remove(key);
      final completion = _delayCompletions[key];
      if (completion != null && !completion.isCompleted) {
        completion.complete(null);
      }
      _delaysChanged();
    },
    onValue: (value) {
      if (value.value case final delay?) {
        delays.putIfAbsent(value.url, () => {})[value.name] = delay;
        final completion = _delayCompletions[_delayKey(value.name, value.url)];
        if (completion != null && !completion.isCompleted) {
          completion.complete(delay);
        }
      }
    },
    onSettled: (_, _) => _delaysChanged(),
    onError: (_, error, _) {
      _operationError = error;
      _delaysChanged();
      return isUnavailableError?.call(error) ?? false;
    },
  );
  final testing = <String>{};
  final delays = <String, Map<String, int>>{};
  final _delayRequests = <String, Future<int?>>{};
  final _delayCompletions = <String, Completer<int?>>{};
  IpingBackendState status = const IpingBackendState();
  IpingTelemetry telemetry = const IpingTelemetry();
  IpingTrafficSnapshot get traffic => telemetry.traffic;
  IpingUserInfo? account;
  IpingSiteConfig siteConfig = const IpingSiteConfig();
  Timer? _timer;
  Future<void>? _refreshing;
  Future<void>? _synchronizing;
  int _epoch = 0;
  int _sessionEpoch = 0;
  int _authorization = 0;
  int _operation = 0;
  final _pending = <int>{};
  int revision = 0;
  int delayRevision = 0;
  bool initialized = false;
  bool authorizing = false;
  bool _disposed = false;
  bool _visible = true;
  Object? _operationError;
  Object? _refreshError;

  bool get signedIn => status.signedIn;
  bool get connected => status.connected;
  bool get pending => _pending.isNotEmpty;
  bool get busy => pending || authorizing || status.busy;
  int get nodes => status.nodes;
  String get email => status.email;
  String get site => status.site;
  String? get error => (_operationError ?? _refreshError)?.toString();
  bool get visible => _visible;

  void setVisible(bool value) {
    if (_disposed || value == _visible) return;
    _visible = value;
    if (value && initialized) unawaited(refresh());
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _delaysChanged() {
    delayRevision++;
    _changed();
  }

  Future<void> initialize({Duration? pollInterval}) async {
    await refresh();
    if (_disposed) return;
    initialized = true;
    if (pollInterval != null) {
      _timer?.cancel();
      _timer = Timer.periodic(pollInterval, (_) {
        if (_visible) unawaited(refresh());
      });
    }
    if (refreshDetails) {
      if (signedIn) unawaited(refreshAccount());
      unawaited(_loadSiteConfig());
    }
    _changed();
  }

  Future<IpingDashboardSnapshot> readDashboard() => backend.readDashboard();

  void receiveState(IpingBackendState value) {
    if (_disposed) return;
    _epoch++;
    _applyState(value);
    if (!value.hasSubscription) telemetry = const IpingTelemetry();
    _changed();
  }

  void _applyState(IpingBackendState value) {
    if (value.signedIn != status.signedIn ||
        value.email != status.email ||
        value.site != status.site) {
      _sessionEpoch++;
      account = null;
    }
    if (!value.connected || !value.hasSubscription) _cancelDelays();
    if (value.connected != status.connected ||
        value.nodes != status.nodes ||
        value.updated != status.updated) {
      revision++;
    }
    status = value;
  }

  Future<void> _loadSiteConfig() async {
    final site = status.site;
    try {
      final value = await backend.readSiteConfig();
      if (_disposed || site != status.site) return;
      siteConfig = value;
      _changed();
    } catch (_) {}
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed) return;
    if (_refreshing case final request?) {
      await request;
      if (!force || _disposed) return;
    }
    if (_refreshing case final request?) return request;
    late final Future<void> request;
    request = _refresh(_epoch).whenComplete(() {
      if (identical(_refreshing, request)) _refreshing = null;
    });
    _refreshing = request;
    return request;
  }

  Future<void> _refresh(int epoch) async {
    try {
      final next = await backend.readState();
      if (_disposed || epoch != _epoch) return;
      final data = next.hasSubscription && !next.busy
          ? await backend.readTelemetry()
          : IpingTelemetry(
              mode: next.hasSubscription ? telemetry.mode : Mode.rule,
            );
      if (_disposed || epoch != _epoch) return;
      _applyState(next);
      telemetry = data;
      _refreshError = null;
    } catch (error) {
      if (!_disposed && epoch == _epoch) _refreshError = error;
    }
    _changed();
  }

  Future<void> refreshAccount() async {
    final epoch = _sessionEpoch;
    try {
      final value = await backend.readAccount();
      if (_disposed || epoch != _sessionEpoch) return;
      account = value;
    } catch (error) {
      if (!_disposed && epoch == _sessionEpoch) _refreshError = error;
    }
    _changed();
  }

  Future<void> signIn({bool register = false}) async {
    if (busy || _disposed) return;
    authorizing = true;
    final authorization = ++_authorization;
    final operation = ++_operation;
    _epoch++;
    _sessionEpoch++;
    _operationError = null;
    _changed();
    try {
      await backend.signIn(register: register);
      if (_disposed || authorization != _authorization) return;
      await refresh(force: true);
      if (signedIn && refreshDetails) await refreshAccount();
    } catch (error) {
      if (!_disposed && operation == _operation) _operationError = error;
      if (throwOnError && !_disposed && authorization == _authorization) {
        rethrow;
      }
    } finally {
      if (!_disposed && authorization == _authorization) {
        authorizing = false;
        _changed();
      }
    }
  }

  void cancelSignIn() {
    if (_disposed) return;
    backend.cancelSignIn();
    _epoch++;
    _sessionEpoch++;
    _authorization++;
    _operation++;
    authorizing = false;
    _changed();
  }

  Future<bool> setConnected(bool connected) =>
      _operate(() => backend.setConnected(connected), overlap: true);

  Future<bool> importSubscription(String url) => _operate(() async {
    final imported = await backend.importSubscription(url);
    if (imported) revision++;
    return imported;
  });

  Future<void> synchronize() {
    if (_synchronizing case final request?) return request;
    late final Future<void> request;
    request =
        _operate(() async {
          await backend.synchronize();
          revision++;
          if (refreshDetails) unawaited(_loadSiteConfig());
          return true;
        }).then<void>((_) {}).whenComplete(() {
          if (identical(_synchronizing, request)) _synchronizing = null;
        });
    return _synchronizing = request;
  }

  Future<void> signOut() async {
    if (authorizing) cancelSignIn();
    _sessionEpoch++;
    _synchronizing = null;
    _pending.clear();
    _cancelDelays();
    await _operate(() async {
      await backend.signOut();
      return true;
    }, overlap: true);
  }

  Future<void> selectProxy(
    String group,
    String name, {
    bool closeConnections = false,
  }) async {
    await _operate(
      () =>
          backend.selectProxy(group, name, closeConnections: closeConnections),
    );
  }

  Future<void> closeConnection(String id) async {
    await _operate(() async {
      if (id.isEmpty) {
        await backend.closeConnections();
      } else {
        await backend.closeConnection(id);
      }
      return true;
    });
  }

  Future<void> setMode(Mode mode) async {
    await _operate(() async {
      await backend.setMode(mode);
      return true;
    });
  }

  Future<void> saveSettings(Map<String, Object?> changes) async {
    await _operate(() async {
      await backend.updateSettings(changes);
      return true;
    }, propagate: true);
  }

  Future<bool> _operate(
    Future<bool> Function() task, {
    bool overlap = false,
    bool propagate = false,
  }) async {
    if (_disposed) return false;
    if (!overlap && busy) {
      if (propagate) throw const IpingBusyException();
      return false;
    }
    final operation = ++_operation;
    _epoch++;
    _pending.add(operation);
    _operationError = null;
    _changed();
    try {
      return await task();
    } catch (error) {
      if (!_disposed && operation == _operation) _operationError = error;
      if (!_disposed &&
          operation == _operation &&
          (throwOnError || propagate)) {
        rethrow;
      }
      return false;
    } finally {
      _pending.remove(operation);
      if (!_disposed) {
        _epoch++;
        await refresh(force: true);
        _changed();
      }
    }
  }

  void _cancelDelays() {
    _delayTasks.cancel();
    final completions = _delayCompletions.values.toList();
    _delayCompletions.clear();
    for (final completion in completions) {
      if (!completion.isCompleted) completion.complete(null);
    }
    testing.clear();
    _delayRequests.clear();
    _delayRunning.clear();
    _delayNames.clear();
  }

  String _delayKey(String name, String? url) =>
      '${url ?? 'https://www.gstatic.com/generate_204'}\u0000$name';

  int? delayFor(String name, String url) => delays[url]?[name];
  bool isTestingDelay(String name, String url) =>
      _delayRequests.containsKey(_delayKey(name, url));
  bool isRunningDelay(String name, String url) =>
      _delayRunning.contains(_delayKey(name, url));

  Future<int?> testDelay(String name, {String? url}) =>
      _testDelays([name], url).single;

  Future<bool> testDelays(Iterable<String> names, {String? url}) async {
    final results = await Future.wait(_testDelays(names, url));
    return results.every((value) => value != null);
  }

  List<Future<int?>> _testDelays(Iterable<String> names, String? url) {
    if (_disposed) return [Future.value()];
    final testUrl = url ?? 'https://www.gstatic.com/generate_204';
    final targets = <IpingDelayTarget>[];
    final completions = <String, Completer<int?>>{};
    final results = <Future<int?>>[];
    for (final name in names) {
      final key = _delayKey(name, testUrl);
      if (_delayRequests[key] case final request?) {
        results.add(request);
        continue;
      }
      testing.add(name);
      _delayNames.update(name, (count) => count + 1, ifAbsent: () => 1);
      final completion = Completer<int?>();
      completions[key] = completion;
      _delayCompletions[key] = completion;
      late final Future<int?> request;
      request = completion.future.whenComplete(() {
        if (identical(_delayRequests[key], request)) {
          _delayRequests.remove(key);
          _delayCompletions.remove(key);
          final remaining = (_delayNames[name] ?? 1) - 1;
          if (remaining == 0) {
            _delayNames.remove(name);
            testing.remove(name);
          } else {
            _delayNames[name] = remaining;
          }
          _delaysChanged();
        }
      });
      _delayRequests[key] = request;
      results.add(request);
      targets.add(
        IpingDelayTarget(proxyName: name, testUrl: testUrl, key: key),
      );
    }
    if (targets.isNotEmpty) {
      _operationError = null;
      unawaited(
        _delayTasks
            .run(targets)
            .then(
              (values) {
                for (final entry in completions.entries) {
                  if (!entry.value.isCompleted) {
                    entry.value.complete(values[entry.key]?.value);
                  }
                }
              },
              onError: (Object error, StackTrace stack) {
                for (final completion in completions.values) {
                  if (!completion.isCompleted) {
                    completion.completeError(error, stack);
                  }
                }
              },
            ),
      );
    }
    _delaysChanged();
    return results;
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _cancelDelays();
    _timer?.cancel();
    if (cancelSignInOnDispose) backend.cancelSignIn();
    super.dispose();
  }
}
