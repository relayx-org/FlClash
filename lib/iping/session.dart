import 'dart:async';
import 'dart:convert';

import 'api.dart';
import 'subscription_url.dart';

class IpingStoredSession {
  const IpingStoredSession({this.account, this.manualUrl})
    : assert(account != null || manualUrl != null);

  final IpingAccount? account;
  final String? manualUrl;
}

String encodeIpingSession(IpingStoredSession session) => jsonEncode({
  ...?session.account?.toJson(),
  'subscription_url': ?session.manualUrl,
});

IpingStoredSession decodeIpingSession(String value) {
  final json = jsonDecode(value) as Map<String, dynamic>;
  final url = json['subscription_url'] as String?;
  if (url != null && !isIpingSubscriptionUrl(url)) {
    throw const FormatException('Invalid subscription URL');
  }
  return IpingStoredSession(
    account: json.containsKey('subscription_token') || url == null
        ? IpingAccount.fromJson(json)
        : null,
    manualUrl: url,
  );
}

abstract interface class IpingSessionStorage {
  Future<IpingStoredSession?> read();
  Future<void> write(IpingStoredSession session);
  Future<void> clear();
}

typedef IpingCachedProfile = ({int nodes, DateTime? updated});

abstract interface class IpingProfileStorage {
  Future<IpingCachedProfile?> read();
  Future<IpingCachedProfile> save(String url, IpingSubscription subscription);
  Future<void> clear();
  Future<void> stop();
}

class IpingSessionState {
  const IpingSessionState({
    this.account,
    this.manualUrl,
    this.busy = false,
    this.initialized = false,
    this.nodes = 0,
    this.updated,
    this.failure,
  });
  final IpingAccount? account;
  final String? manualUrl;
  final bool busy;
  final bool initialized;
  final int nodes;
  final DateTime? updated;
  final IpingFailure? failure;

  bool get hasSubscription => account != null || manualUrl != null;
  bool get canConnect => hasSubscription && nodes > 0;
}

class IpingSession {
  IpingSession({
    required this.api,
    required this.storage,
    required this.profiles,
    required this.onChanged,
    required this.authenticate,
    required this.cancelAuthentication,
  });
  final IpingApi api;
  final Future<IpingAccount?> Function(bool register) authenticate;
  final void Function() cancelAuthentication;
  final IpingSessionStorage storage;
  final IpingProfileStorage profiles;
  final void Function(IpingSessionState state) onChanged;
  IpingSessionState state = const IpingSessionState();
  IpingStoredSession? _session;
  int _epoch = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void>? _sync;

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  void _publish({
    bool busy = false,
    IpingCachedProfile? profile,
    IpingFailure? failure,
  }) {
    if (_disposed) return;
    state = IpingSessionState(
      account: _session?.account,
      manualUrl: _session?.manualUrl,
      initialized: true,
      busy: busy,
      nodes: profile?.nodes ?? state.nodes,
      updated: profile == null ? state.updated : profile.updated,
      failure: failure,
    );
    onChanged(state);
  }

  Future<void> _commit(int epoch, Future<void> Function() action) {
    final operation = _writes.then((_) async {
      if (_current(epoch)) await action();
    });
    _writes = operation.then((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> initialize() async {
    final epoch = ++_epoch;
    _publish(busy: true);
    try {
      final session = await storage.read();
      if (!_current(epoch)) return;
      _session = session;
      if (session == null) {
        await _commit(epoch, () async {
          try {
            await profiles.stop();
          } finally {
            await profiles.clear();
          }
        });
        _publish(profile: (nodes: 0, updated: null));
        return;
      }
      final cached = await profiles.read();
      if (!_current(epoch)) return;
      _publish(busy: true, profile: cached);
      await _synchronize(epoch);
    } catch (_) {
      if (!_current(epoch)) return;
      try {
        await _commit(epoch, profiles.stop);
      } catch (_) {
        // A storage error must still leave the local connection gate closed.
      }
      if (_current(epoch)) {
        _publish(
          profile: (nodes: 0, updated: null),
          failure: IpingFailure.storage,
        );
      }
    }
  }

  Future<void> signIn({bool register = false}) async {
    if (state.busy) return;
    final epoch = ++_epoch;
    _publish(busy: true);
    try {
      final account = await authenticate(register);
      if (account == null) {
        if (_current(epoch)) _publish();
        return;
      }
      if (!_current(epoch)) return;
      if (_session != null && _session!.account?.id != account.id) {
        _publish(busy: true, profile: (nodes: 0, updated: null));
        await _commit(epoch, () async {
          await profiles.stop();
          await profiles.clear();
        });
      }
      if (!_current(epoch)) return;
      final session = IpingStoredSession(account: account);
      await _commit(epoch, () => storage.write(session));
      if (!_current(epoch)) return;
      _session = session;
      _publish(busy: true);
      await _synchronize(epoch);
    } on IpingException catch (error) {
      if (_current(epoch)) _publish(failure: error.failure);
    } catch (_) {
      if (_current(epoch)) _publish(failure: IpingFailure.storage);
    }
  }

  void cancelSignIn() {
    cancelAuthentication();
    _epoch++;
    _publish();
  }

  Future<bool> importSubscription(String value) async {
    if (state.busy || _disposed) return false;
    final url = value.trim();
    if (!isIpingSubscriptionUrl(url)) {
      _publish(failure: IpingFailure.subscription);
      return false;
    }
    final epoch = ++_epoch;
    final previous = _session;
    final next = IpingStoredSession(account: previous?.account, manualUrl: url);
    _publish(busy: true);
    try {
      final subscription = await api.subscription(url);
      if (!_current(epoch)) return false;
      IpingCachedProfile? saved;
      await _commit(epoch, () async {
        await storage.write(next);
        try {
          if (subscription.nodes == 0) await profiles.stop();
          saved = await profiles.save(url, subscription);
        } catch (_) {
          if (previous == null) {
            await storage.clear();
          } else {
            await storage.write(previous);
          }
          rethrow;
        }
      });
      if (!_current(epoch)) return false;
      _session = next;
      _publish(profile: saved);
      return true;
    } on IpingException catch (error) {
      if (_current(epoch)) {
        _publish(
          failure: error.failure == IpingFailure.session
              ? IpingFailure.subscription
              : error.failure,
        );
      }
    } catch (_) {
      if (_current(epoch)) _publish(failure: IpingFailure.storage);
    }
    return false;
  }

  Future<void> synchronize() {
    if (_session == null) return Future.value();
    if (_sync != null) return _sync!;
    if (state.busy) return Future.value();
    late final Future<void> operation;
    operation = _synchronize(_epoch).whenComplete(() {
      if (identical(_sync, operation)) _sync = null;
    });
    return _sync = operation;
  }

  Future<void> _synchronize(int epoch) async {
    if (!_current(epoch)) return;
    _publish(busy: true);
    try {
      final manualUrl = _session!.manualUrl;
      final url =
          manualUrl ??
          api.subscriptionUrl(_session!.account!.subscriptionToken);
      final subscription = await api.subscription(url);
      if (!_current(epoch)) return;
      IpingCachedProfile? saved;
      await _commit(epoch, () async {
        if (subscription.nodes == 0) {
          _publish(busy: true, profile: (nodes: 0, updated: state.updated));
          await profiles.stop();
        }
        saved = await profiles.save(url, subscription);
      });
      if (_current(epoch)) _publish(profile: saved);
    } on IpingException catch (error) {
      if (!_current(epoch)) return;
      if (error.failure == IpingFailure.session &&
          _session?.manualUrl == null) {
        await signOut();
        if (!_disposed) _publish(failure: IpingFailure.session);
      } else {
        _publish(
          failure: error.failure == IpingFailure.session
              ? IpingFailure.subscription
              : error.failure,
        );
      }
    } catch (_) {
      if (_current(epoch)) _publish(failure: IpingFailure.storage);
    }
  }

  Future<void> signOut() async {
    cancelAuthentication();
    final epoch = ++_epoch;
    _session = null;
    _sync = null;
    _publish(busy: true, profile: (nodes: 0, updated: null));
    try {
      await _commit(epoch, () async {
        try {
          await profiles.stop();
        } finally {
          try {
            await storage.clear();
          } finally {
            await profiles.clear();
          }
        }
      });
      if (_current(epoch)) {
        state = const IpingSessionState(initialized: true);
        onChanged(state);
      }
    } catch (_) {
      if (_current(epoch)) _publish(failure: IpingFailure.storage);
    }
  }

  void dispose() {
    cancelAuthentication();
    _disposed = true;
    _epoch++;
  }
}
