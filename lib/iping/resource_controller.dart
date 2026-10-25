import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_resources.dart';

class IpingResourceController<T, K> extends ChangeNotifier {
  IpingResourceController(this.store, {required this.keyOf});

  final IpingResourceStore<T> store;
  final K Function(T item) keyOf;
  List<T>? _items;
  List<T>? get items => _items;
  Object? error;
  bool busy = false;
  bool _disposed = false;
  bool writing = false;
  int _generation = 0;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(
    Future<List<T>> Function(bool Function() current) task,
  ) async {
    if (busy || _disposed) return false;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    busy = true;
    error = null;
    _changed();
    try {
      final items = await task(current);
      if (!current()) return false;
      _items = List.unmodifiable(items);
      return true;
    } catch (exception) {
      if (current() && writing) {
        try {
          final persisted = await store.read();
          if (current()) _items = List.unmodifiable(persisted);
        } catch (_) {}
      }
      if (current()) error = exception;
      return false;
    } finally {
      if (current()) {
        busy = false;
        writing = false;
        _changed();
      }
    }
  }

  Future<bool> load() => _run((_) async => await store.read());

  Future<bool> _mutate(
    List<T> Function(List<T> current) update, {
    Future<void> Function()? validate,
  }) => _run((current) async {
    if (validate != null) await validate();
    if (!current()) return const [];
    final previous = await store.read();
    if (!current()) return previous;
    final next = update(previous);
    writing = true;
    return store.write(next);
  });

  void cancelPending() {
    if (_disposed || !busy || writing) return;
    _generation++;
    busy = false;
    error = null;
    _changed();
  }

  void clearError() {
    error = null;
    _changed();
  }

  Future<bool> put(T item, {K? replacing}) => _mutate(
    (current) {
      final key = keyOf(item);
      if (current.any(
        (value) => keyOf(value) == key && keyOf(value) != replacing,
      )) {
        throw const IpingResourceException(IpingResourceIssue.duplicate);
      }
      if (replacing == null) return [...current, item];
      if (!current.any((value) => keyOf(value) == replacing)) {
        throw const IpingResourceException(IpingResourceIssue.missing);
      }
      return [
        for (final value in current) keyOf(value) == replacing ? item : value,
      ];
    },
    validate: () async {
      final message = await store.validate(item);
      if (message != null) {
        throw IpingResourceException(
          IpingResourceIssue.invalid,
          message: message,
        );
      }
    },
  );

  Future<bool> insertAll(List<T> items, {bool atStart = false}) => _mutate(
    (current) {
      final keys = {for (final value in current) keyOf(value)};
      for (final item in items) {
        if (!keys.add(keyOf(item))) {
          throw const IpingResourceException(IpingResourceIssue.duplicate);
        }
      }
      return atStart ? [...items, ...current] : [...current, ...items];
    },
    validate: () async {
      for (final item in items) {
        final error = await store.validate(item);
        if (error != null) {
          throw IpingResourceException(
            IpingResourceIssue.invalid,
            message: error,
          );
        }
      }
    },
  );

  Future<bool> replaceAll(List<T> items) => _mutate((_) => List.of(items));

  Future<bool> remove(Set<K> keys) => _mutate(
    (current) => current.where((item) => !keys.contains(keyOf(item))).toList(),
  );

  Future<bool> reorder(int oldIndex, int newIndex) {
    final order = [for (final item in _items ?? <T>[]) keyOf(item)];
    if (oldIndex < 0 ||
        oldIndex >= order.length ||
        newIndex < 0 ||
        newIndex >= order.length) {
      return Future.value(false);
    }
    order.insert(newIndex, order.removeAt(oldIndex));
    return reorderKeys(order);
  }

  Future<bool> reorderKeys(List<K> order) => _mutate((current) {
    final byKey = {for (final item in current) keyOf(item): item};
    return [for (final key in order) ?byKey.remove(key), ...byKey.values];
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
