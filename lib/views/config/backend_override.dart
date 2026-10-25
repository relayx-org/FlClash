import 'package:collection/collection.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'override.dart';

class BackendOverrideTarget<K extends OverrideKey, M>
    extends PatchOverrideTarget<K, M> {
  const BackendOverrideTarget({
    required super.get,
    required super.set,
    required super.description,
    required this.section,
    required this.values,
  });

  final String section;
  final Map<String, Object?> Function(M model) values;

  @override
  void update(
    WidgetRef ref,
    OverrideState<K, M> Function(OverrideState<K, M>) update,
  ) {
    final previous = read(ref);
    final next = update(previous);
    final before = values(previous.model);
    final after = values(next.model);
    const equality = DeepCollectionEquality();
    final changes = {
      for (final key in {...previous.keys, ...next.keys})
        if (!next.keys.contains(key))
          '$section.${key.path}': null
        else if (!previous.keys.contains(key) ||
            !equality.equals(before[key.path], after[key.path]))
          '$section.${key.path}': after[key.path],
    };
    globalState.safeRun(
      () => ref.read(ipingBackendProvider).updateSettings(changes),
    );
  }
}
