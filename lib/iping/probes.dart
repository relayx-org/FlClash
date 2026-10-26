import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend.dart';

Future<Map<String, ProbeAnswer<IpInfo>>> outboundProbeAnswers(
  String target,
  RouteState route,
  Future<ProbeAnswer<IpInfo>> Function(String proxyName) lookup,
) async {
  final result = await lookup(
    target.isEmpty && !route.proxied ? 'DIRECT' : target,
  );
  final value = result.value;
  final exit = result.chains.firstOrNull;
  return {
    target: result,
    if (value != null && exit != null && exit != target)
      exit: ProbeAnswer(
        value: value,
        coreEpoch: result.coreEpoch,
        picksVersion: result.picksVersion,
        chains: [exit],
      ),
  };
}

bool isServiceProbeFailure(ServiceCheck value) =>
    value.status == ServiceProbeStatus.timeout ||
    value.status == ServiceProbeStatus.failed;

class IpingProbes extends ChangeNotifier {
  IpingProbes(this.backend) {
    outbound = RoutedProbeController<String, IpInfo>(
      probe: (target, route) =>
          outboundProbeAnswers(target, route, backend.lookupOutboundIp),
      onAttach: () => unawaited(refreshRoute()),
      onResync: () => unawaited(refreshRoute()),
    )..addListener(_outboundChanged);
    services = RoutedProbeController<ServiceTarget, ServiceCheck>(
      probe: (target, route) =>
          backend.checkServices(route.proxied ? '' : 'DIRECT', [target]),
      isFailure: isServiceProbeFailure,
      onAttach: () => unawaited(refreshRoute()),
      onResync: () => unawaited(refreshRoute()),
    )..addListener(_changed);
  }

  final IpingBackend backend;
  late final RoutedProbeController<String, IpInfo> outbound;
  late final RoutedProbeController<ServiceTarget, ServiceCheck> services;
  Future<void>? _reading;
  int _generation = 0;
  bool _disposed = false;
  bool _visible = true;
  int _resumes = 0;
  int revision = 0;
  Object? error;
  final _quality =
      <String, ({IpQuality? value, Object? error, DateTime? failedAt})>{};
  final _qualityRequests = <String, Future<void>>{};

  IpQuality? qualityOf(String ip) => _quality[ip]?.value;
  Object? qualityErrorOf(String ip) => _quality[ip]?.error;
  bool isQualityLoading(String ip) => _qualityRequests.containsKey(ip);

  void _changed() {
    revision++;
    notifyListeners();
  }

  void setVisible(bool value) {
    if (_disposed || value == _visible) return;
    _visible = value;
    outbound.setVisible(value);
    services.setVisible(value);
    if (value) {
      _resumes++;
      unawaited(refreshRoute());
    }
  }

  void _outboundChanged() {
    final ip = outbound.state.valueOf('')?.ip;
    if (ip != null) unawaited(loadQuality(ip));
    _changed();
  }

  Future<void> loadQuality(String ip, {bool force = false}) {
    if (_disposed) return Future.value();
    if (_qualityRequests[ip] case final pending?) return pending;
    final cached = _quality[ip];
    if (!force &&
        cached != null &&
        (cached.value != null ||
            DateTime.now().difference(cached.failedAt!) <
                const Duration(minutes: 5))) {
      return Future.value();
    }
    late final Future<void> request;
    request = _loadQuality(ip).whenComplete(() {
      if (identical(_qualityRequests[ip], request)) _qualityRequests.remove(ip);
      if (!_disposed) _changed();
    });
    _qualityRequests[ip] = request;
    _changed();
    return request;
  }

  Future<void> _loadQuality(String ip) async {
    try {
      final value = await backend.readIpQuality(ip);
      if (!_disposed) {
        _quality[ip] = (value: value, error: null, failedAt: null);
      }
    } catch (failure) {
      if (!_disposed) {
        _quality[ip] = (value: null, error: failure, failedAt: DateTime.now());
      }
    }
  }

  void refreshOutbound() {
    final ip = outbound.state.valueOf('')?.ip;
    outbound.refresh(const ['']);
    if (ip != null && qualityErrorOf(ip) != null) {
      unawaited(loadQuality(ip, force: true));
    }
  }

  Future<void> refreshRoute() {
    if (_disposed) return Future.value();
    if (_reading case final request?) return request;
    late final Future<void> request;
    request = _readRoute(_generation).whenComplete(() {
      if (identical(_reading, request)) _reading = null;
    });
    return _reading = request;
  }

  Future<void> _readRoute(int generation) async {
    try {
      final route = await backend.readProbeRoute();
      if (_disposed || generation != _generation) return;
      final current = route.copyWith(hostEpoch: generation, resumes: _resumes);
      if (error == null && current == outbound.route) return;
      error = null;
      outbound.receiveRoute(current);
      services.receiveRoute(current);
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
      outbound.receiveRoute(RouteState(hostEpoch: generation));
      services.receiveRoute(RouteState(hostEpoch: generation));
    }
    _changed();
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _reading = null;
    error = null;
    outbound.receiveRoute(RouteState(hostEpoch: _generation));
    services.receiveRoute(RouteState(hostEpoch: _generation));
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    outbound.dispose();
    services.dispose();
    super.dispose();
  }
}
