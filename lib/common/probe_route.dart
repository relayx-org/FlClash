import 'package:flutter/foundation.dart';

/// Freshness requires the Core's synchronized counters.
@immutable
class RouteState {
  const RouteState({
    this.coreEpoch = 0,
    this.picksVersion = 0,
    this.picks = const {},
    this.hostEpoch = 0,
    this.proxied = false,
    this.synced = false,
    this.live = false,
    this.resumes = 0,
  });

  final int coreEpoch;
  final int picksVersion;
  final Map<String, String> picks;
  final int hostEpoch;
  final bool proxied;
  final bool synced;
  final bool live;
  final int resumes;

  RouteState copyWith({
    int? coreEpoch,
    int? picksVersion,
    Map<String, String>? picks,
    int? hostEpoch,
    bool? proxied,
    bool? synced,
    bool? live,
    int? resumes,
  }) {
    return RouteState(
      coreEpoch: coreEpoch ?? this.coreEpoch,
      picksVersion: picksVersion ?? this.picksVersion,
      picks: picks ?? this.picks,
      hostEpoch: hostEpoch ?? this.hostEpoch,
      proxied: proxied ?? this.proxied,
      synced: synced ?? this.synced,
      live: live ?? this.live,
      resumes: resumes ?? this.resumes,
    );
  }

  /// Unnamed groups cannot contradict a chain; an answer without a chain
  /// belongs to the entire selection version it was made under.
  bool isFresh(RouteStamp stamp) {
    if (!synced ||
        stamp.coreEpoch != coreEpoch ||
        stamp.hostEpoch != hostEpoch ||
        stamp.proxied != proxied) {
      return false;
    }
    final chains = stamp.chains;
    if (chains.isEmpty) {
      return stamp.picksVersion == picksVersion;
    }
    for (var i = chains.length - 1; i >= 1; i--) {
      final next = picks[chains[i]];
      if (next != null && next != chains[i - 1]) {
        return false;
      }
    }
    return true;
  }

  bool isBehind(RouteStamp stamp) =>
      stamp.coreEpoch > coreEpoch || stamp.picksVersion > picksVersion;

  @override
  bool operator ==(Object other) =>
      other is RouteState &&
      other.coreEpoch == coreEpoch &&
      other.picksVersion == picksVersion &&
      mapEquals(other.picks, picks) &&
      other.hostEpoch == hostEpoch &&
      other.proxied == proxied &&
      other.synced == synced &&
      other.live == live &&
      other.resumes == resumes;

  @override
  int get hashCode => Object.hash(
    coreEpoch,
    picksVersion,
    Object.hashAllUnordered(
      picks.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    hostEpoch,
    proxied,
    synced,
    live,
    resumes,
  );
}

/// The route a probe answer was produced under: the Core's counters when it
/// started, the host's when it was sent, and the chain it went through.
@immutable
class RouteStamp {
  const RouteStamp({
    required this.coreEpoch,
    required this.picksVersion,
    required this.hostEpoch,
    required this.proxied,
    this.chains = const [],
  });

  final int coreEpoch;
  final int picksVersion;
  final int hostEpoch;
  final bool proxied;
  final List<String> chains;

  @override
  bool operator ==(Object other) =>
      other is RouteStamp &&
      other.coreEpoch == coreEpoch &&
      other.picksVersion == picksVersion &&
      other.hostEpoch == hostEpoch &&
      other.proxied == proxied &&
      listEquals(other.chains, chains);

  @override
  int get hashCode => Object.hash(
    coreEpoch,
    picksVersion,
    hostEpoch,
    proxied,
    Object.hashAll(chains),
  );
}
