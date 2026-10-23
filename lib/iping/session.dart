import 'dart:async';
import 'dart:convert';

import 'api.dart';

typedef IpingStoredSession = IpingAccount;

String encodeIpingSession(IpingAccount account) => jsonEncode(account.toJson());
IpingAccount decodeIpingSession(String value) =>
    IpingAccount.fromJson(jsonDecode(value) as Map<String, dynamic>);

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
    this.busy = false,
    this.initialized = false,
    this.nodes = 0,
    this.updated,
    this.failure,
  });
  final IpingStoredSession? account;
  final bool busy;
  final bool initialized;
  final int nodes;
  final DateTime? updated;
  final IpingFailure? failure;

  bool get canConnect => account != null && nodes > 0;
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
  IpingStoredSession? _account;
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
      account: _account,
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
      final account = await storage.read();
      if (!_current(epoch)) return;
      _account = account;
      if (account == null) {
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
      if (_account != null && _account!.id != account.id) {
        _publish(busy: true, profile: (nodes: 0, updated: null));
        await _commit(epoch, () async {
          await profiles.stop();
          await profiles.clear();
        });
      }
      if (!_current(epoch)) return;
      await _commit(epoch, () => storage.write(account));
      if (!_current(epoch)) return;
      _account = account;
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

  Future<void> synchronize() {
    if (_account == null) return Future.value();
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
      final url = api.subscriptionUrl(_account!.subscriptionToken);
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
      if (error.failure == IpingFailure.session) {
        await signOut();
        if (!_disposed) _publish(failure: IpingFailure.session);
      } else {
        _publish(failure: error.failure);
      }
    } catch (_) {
      if (_current(epoch)) _publish(failure: IpingFailure.storage);
    }
  }

  Future<void> signOut() async {
    cancelAuthentication();
    final epoch = ++_epoch;
    _account = null;
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
