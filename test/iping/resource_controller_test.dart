import 'dart:async';

import 'package:fl_clash/iping/backend_resources.dart';
import 'package:fl_clash/iping/resource_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements IpingResourceStore<Filter> {
  List<Filter> items = const [Filter(label: 'A', regex: 'a')];
  bool fail = false;
  bool canonicalize = false;
  bool partialFailure = false;
  int writes = 0;
  Completer<String?>? validation;

  @override
  int? get itemLimit => null;

  @override
  List<Filter> read() => items;

  @override
  Future<List<Filter>> write(List<Filter> next) async {
    if (fail) throw StateError('disk unavailable');
    items = canonicalize
        ? [
            for (final item in next)
              item.copyWith(label: item.label.toUpperCase()),
          ]
        : List.of(next);
    writes++;
    if (partialFailure) throw StateError('later file write failed');
    return items;
  }

  @override
  Future<String?> validate(Filter item) async => item.regex == 'pending'
      ? await validation!.future
      : item.regex == 'invalid'
      ? 'invalid regex'
      : null;
}

void main() {
  late _Store store;
  late IpingResourceController<Filter, String> controller;

  setUp(() {
    store = _Store();
    controller = IpingResourceController(store, keyOf: (item) => item.label);
  });
  tearDown(() => controller.dispose());

  test(
    'a partial storage failure refreshes the persisted snapshot and keeps the error',
    () async {
      await controller.load();
      store.partialFailure = true;
      expect(
        await controller.put(const Filter(label: 'B', regex: 'b')),
        isFalse,
      );
      expect(controller.items!.map((item) => item.label), ['A', 'B']);
      expect(controller.error, isA<StateError>());
      expect(controller.busy, isFalse);
    },
  );

  test(
    'reorder keeps the displayed identities when new resources arrive before the write',
    () async {
      store.items = [
        const Filter(label: 'A', regex: 'a'),
        const Filter(label: 'B', regex: 'b'),
      ];
      await controller.load();
      store.items = [...store.items, const Filter(label: 'C', regex: 'c')];
      expect(await controller.reorderKeys(['B', 'A']), isTrue);
      expect(controller.items!.map((item) => item.label), ['B', 'A', 'C']);
    },
  );

  test('a save publishes the canonical storage result', () async {
    store.canonicalize = true;
    expect(
      await controller.put(const Filter(label: 'lower', regex: 'x')),
      isTrue,
    );
    expect(controller.items!.last.label, 'LOWER');
    expect(await controller.remove({'LOWER'}), isTrue);
    expect(store.items.map((item) => item.label), ['A']);
  });

  test('edits merge with fresh data and keep immutable snapshots', () async {
    await controller.load();
    final previous = controller.items!;
    store.items = [...store.items, const Filter(label: 'B', regex: 'b')];
    expect(
      await controller.put(
        const Filter(label: 'Renamed', regex: 'aa'),
        replacing: 'A',
      ),
      isTrue,
    );
    expect(controller.items!.map((item) => item.label), ['Renamed', 'B']);
    expect(previous.single.label, 'A');
    expect(() => previous.clear(), throwsUnsupportedError);
    expect(await controller.reorder(0, 1), isTrue);
    expect(controller.items!.first.label, 'B');
    expect(await controller.remove({'Renamed'}), isTrue);
    expect(controller.items!.single.label, 'B');
  });

  test('duplicate, invalid and missing entries never reach storage', () async {
    await controller.load();
    expect(
      await controller.put(const Filter(label: 'B', regex: 'invalid')),
      isFalse,
    );
    expect(
      (controller.error as IpingResourceException).message,
      'invalid regex',
    );
    expect(await controller.put(const Filter(label: 'A', regex: 'a')), isFalse);
    expect(
      (controller.error as IpingResourceException).issue,
      IpingResourceIssue.duplicate,
    );
    expect(
      await controller.put(
        const Filter(label: 'B', regex: 'b'),
        replacing: 'missing',
      ),
      isFalse,
    );
    expect(
      (controller.error as IpingResourceException).issue,
      IpingResourceIssue.missing,
    );
    expect(store.writes, 0);
    expect(controller.busy, isFalse);
  });

  test('a failed write retains the list and releases retry controls', () async {
    await controller.load();
    store.fail = true;
    expect(await controller.remove({'A'}), isFalse);
    expect(controller.items!.single.label, 'A');
    expect(controller.busy, isFalse);
    expect(controller.writing, isFalse);
    store.fail = false;
    expect(await controller.remove({'A'}), isTrue);
    expect(controller.items, isEmpty);
    expect(controller.error, isNull);
  });

  test(
    'canceling validation lets a new edit finish without a stale save',
    () async {
      await controller.load();
      store.validation = Completer<String?>();
      final pending = controller.put(
        const Filter(label: 'Old', regex: 'pending'),
      );
      expect(controller.busy, isTrue);
      controller.cancelPending();
      expect(
        await controller.put(const Filter(label: 'New', regex: 'new')),
        isTrue,
      );
      store.validation!.complete(null);
      expect(await pending, isFalse);
      expect(store.items.map((item) => item.label), ['A', 'New']);
      expect(store.writes, 1);
      expect(controller.busy, isFalse);
    },
  );
}
