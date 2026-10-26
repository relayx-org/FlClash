import 'dart:async';

import 'package:flutter/foundation.dart';
import 'probe_route.dart';
export 'probe_route.dart';

enum ProbePhase { empty, probing, fresh, failed }

@immutable
class ProbeEntry<V> {
  const ProbeEntry({required this.phase, this.value, this.stamp});

  final ProbePhase phase;
  final V? value;
  final RouteStamp? stamp;

  bool get isLoading => phase == ProbePhase.probing;

  @override
  bool operator ==(Object other) =>
      other is ProbeEntry<V> &&
      other.phase == phase &&
      other.value == value &&
      other.stamp == stamp;

  @override
  int get hashCode => Object.hash(phase, value, stamp);
}

@immutable
class RoutedProbeState<K, V> {
  const RoutedProbeState([this.entries = const {}]);

  final Map<K, ProbeEntry<V>> entries;

  ProbeEntry<V> entryOf(K target) =>
      entries[target] ?? ProbeEntry<V>(phase: ProbePhase.empty);

  V? valueOf(K target) => entries[target]?.value;

  bool isLoading(K target) => entryOf(target).isLoading;

  @override
  bool operator ==(Object other) =>
      other is RoutedProbeState<K, V> && mapEquals(other.entries, entries);

  @override
  int get hashCode => Object.hashAllUnordered(
    entries.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

/// One probe answer before it is stamped. The counters are the Core's at
/// launch and stay null when the Core gave no answer at all.
class ProbeAnswer<V> {
  const ProbeAnswer({
    this.value,
    this.coreEpoch,
    this.picksVersion,
    this.chains = const [],
  });

  final V? value;
  final int? coreEpoch;
  final int? picksVersion;
  final List<String> chains;
}

/// Keeps one answer per target and only ever shows one that still describes
/// the current route. State changes are deferred to a microtask, so a widget
/// may watch a target from its build.
class RoutedProbeController<K, V> extends ChangeNotifier {
  RoutedProbeController({
    required this.probe,
    RouteState route = const RouteState(),
    bool visible = true,
    this.isFailure,
    this.onAttach,
    this.onDetach,
    this.onResync,
    this.onError,
  }) : _route = route,
       _visible = visible;

  final Future<Map<K, ProbeAnswer<V>>> Function(K target, RouteState route)
  probe;
  final bool Function(V value)? isFailure;
  final VoidCallback? onAttach;
  final VoidCallback? onDetach;
  final VoidCallback? onResync;
  final void Function(Object error)? onError;
  bool _visible;
  bool _disposed = false;
  RoutedProbeState<K, V> _state = RoutedProbeState<K, V>();
  RoutedProbeState<K, V> get state => _state;
  set state(RoutedProbeState<K, V> value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  void setVisible(bool value) {
    _visible = value;
    if (value && _due.isNotEmpty) _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _due.clear();
    _inFlight.clear();
    super.dispose();
  }

  final Map<K, int> _watchers = {};
  final Map<K, ({bool keepValue, bool forced, bool supersede})> _due = {};
  final Map<K, int> _inFlight = {};
  int _runs = 0;
  final Map<K, RouteState> _staleUnder = {};
  bool _scheduled = false;
  RouteState _route;
  RouteState get route => _route;

  void watch(K target) {
    final count = _watchers[target] ?? 0;
    _watchers[target] = count + 1;
    if (count > 0) {
      return;
    }
    if (_watchers.length == 1) {
      onAttach?.call();
    }
    if (_entryOf(target).phase != ProbePhase.fresh) {
      _mark(target);
    }
  }

  void unwatch(K target) {
    final count = _watchers[target];
    if (count == null) {
      return;
    }
    if (count > 1) {
      _watchers[target] = count - 1;
      return;
    }
    _watchers.remove(target);
    final due = _due[target];
    if (due != null && !due.forced) {
      _due.remove(target);
      scheduleMicrotask(() => _forget(target));
    }
    if (_watchers.isEmpty && !_disposed) {
      onDetach?.call();
    }
  }

  /// A re-probe dropped before it launched would leave its entry loading
  /// with nothing left to settle it.
  void _forget(K target) {
    if (_disposed ||
        _watchers.containsKey(target) ||
        _due.containsKey(target) ||
        _inFlight.containsKey(target) ||
        !_entryOf(target).isLoading) {
      return;
    }
    state = RoutedProbeState(Map.of(state.entries)..remove(target));
  }

  /// A refresh is the user asking, so it runs for targets nobody watches
  /// too; the answer lands in the cache and stays until the route moves.
  void refresh(Iterable<K> targets) {
    for (final target in targets) {
      _mark(target, keepValue: true, forced: true);
    }
  }

  ProbeEntry<V> _entryOf(K target) => state.entryOf(target);

  void _mark(K target, {bool keepValue = false, bool forced = false}) {
    if (_inFlight.containsKey(target)) {
      return;
    }
    final previous = _due[target];
    _due[target] = (
      keepValue: keepValue || (previous?.keepValue ?? false),
      forced: forced || (previous?.forced ?? false),
      supersede: previous?.supersede ?? false,
    );
    _schedule();
  }

  void _schedule() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    scheduleMicrotask(_launch);
  }

  void _launch() {
    _scheduled = false;
    if (_disposed || !_route.live || !_visible) {
      return;
    }
    final route = _route;
    final targets = <K>[];
    final entries = Map<K, ProbeEntry<V>>.of(state.entries);
    for (final MapEntry(key: target, value: due) in _due.entries) {
      final wanted = due.forced || _watchers.containsKey(target);
      if (!wanted || (_inFlight.containsKey(target) && !due.supersede)) {
        continue;
      }
      targets.add(target);
      entries[target] = ProbeEntry(
        phase: ProbePhase.probing,
        value: due.keepValue ? entries[target]?.value : null,
      );
    }
    _due.clear();
    if (targets.isEmpty) {
      return;
    }
    state = RoutedProbeState(entries);
    final run = ++_runs;
    for (final target in targets) {
      _inFlight[target] = run;
    }
    for (final target in targets) {
      unawaited(_run(target, route, run));
    }
  }

  /// A target a newer route asked again belongs to that run from then on.
  Future<void> _run(K target, RouteState route, int run) async {
    var answers = <K, ProbeAnswer<V>>{};
    try {
      answers = await probe(target, route);
    } catch (error) {
      onError?.call(error);
    }
    if (_disposed || _inFlight[target] != run) {
      return;
    }
    _inFlight.remove(target);
    final current = _route;
    final entries = Map<K, ProbeEntry<V>>.of(state.entries);
    final answer = answers[target] ?? const ProbeAnswer();
    final stamp = _stampOf(answer, route);
    final fresh = current.isFresh(stamp);
    final behind = !fresh && current.isBehind(stamp);
    if (!fresh) {
      // Stale twice under one route: the Core and host disagree, stop asking.
      if (_staleUnder[target] != current) {
        _staleUnder[target] = current;
        _invalidate(target, entries);
      } else if (_watchers.containsKey(target)) {
        entries[target] = ProbeEntry(phase: ProbePhase.failed, stamp: stamp);
      } else {
        entries.remove(target);
      }
    } else {
      _staleUnder.remove(target);
      final value = answer.value;
      final failed = value == null || (isFailure?.call(value) ?? false);
      entries[target] = ProbeEntry(
        phase: failed ? ProbePhase.failed : ProbePhase.fresh,
        value: value,
        stamp: stamp,
      );
    }
    for (final MapEntry(key: other, value: answer) in answers.entries) {
      final value = answer.value;
      if (other == target ||
          value == null ||
          (isFailure?.call(value) ?? false)) {
        continue;
      }
      final stamp = _stampOf(answer, route);
      if (!current.isFresh(stamp)) {
        continue;
      }
      _inFlight.remove(other);
      _due.remove(other);
      entries[other] = ProbeEntry(
        phase: ProbePhase.fresh,
        value: value,
        stamp: stamp,
      );
    }
    state = RoutedProbeState(entries);
    if (behind) {
      onResync?.call();
    }
    if (_due.isNotEmpty) {
      _schedule();
    }
  }

  RouteStamp _stampOf(ProbeAnswer<V> answer, RouteState route) => RouteStamp(
    coreEpoch: answer.coreEpoch ?? route.coreEpoch,
    picksVersion: answer.picksVersion ?? route.picksVersion,
    hostEpoch: route.hostEpoch,
    proxied: route.proxied,
    chains: answer.chains,
  );

  void receiveRoute(RouteState next) {
    final previous = _route;
    _route = next;
    final entries = Map<K, ProbeEntry<V>>.of(state.entries);
    final resumed = next.resumes != previous.resumes;
    // Picks flip whenever any url-test or fallback group re-picks, often
    // faster than a probe finishes; restarting on them would never let one
    // land. An answer's chain tells when it went through a group that moved.
    final moved =
        (next.coreEpoch != previous.coreEpoch ||
        next.hostEpoch != previous.hostEpoch ||
        next.proxied != previous.proxied);
    for (final MapEntry(key: target, value: entry) in state.entries.entries) {
      if (_inFlight.containsKey(target)) {
        if (moved) {
          _invalidate(target, entries);
        }
        continue;
      }
      final stamp = entry.stamp;
      if (stamp == null) {
        continue;
      }
      if (!next.isFresh(stamp)) {
        _invalidate(target, entries);
      } else if (resumed &&
          entry.phase == ProbePhase.failed &&
          _watchers.containsKey(target)) {
        _due[target] = (keepValue: false, forced: false, supersede: false);
      }
    }
    if (!mapEquals(entries, state.entries)) {
      state = RoutedProbeState(entries);
    }
    if (_due.isNotEmpty) {
      _schedule();
    }
  }

  /// A stale entry is asked again while someone watches it and forgotten
  /// otherwise; either way its old value is never shown.
  void _invalidate(K target, Map<K, ProbeEntry<V>> entries) {
    if (_watchers.containsKey(target)) {
      entries[target] = ProbeEntry(phase: ProbePhase.probing);
      _due[target] = (keepValue: false, forced: false, supersede: true);
    } else {
      _inFlight.remove(target);
      entries.remove(target);
    }
  }
}
