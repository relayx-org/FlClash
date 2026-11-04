import 'package:fl_clash/iping/dashboard_defaults.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

IpingDashboardCard _card(String id) => IpingDashboardCard(
  id: id,
  label: (_) => id,
  builder: (_) => const SizedBox.shrink(),
);

List<String> _ids(Iterable<IpingDashboardCard> cards) => [
  for (final card in cards) card.id,
];

void main() {
  final all = [_card('status'), _card('speed'), _card('mode'), _card('memory')];
  const defaultIds = ['status', 'speed', 'mode'];

  test('shows the default cards in order with the rest available', () {
    final editor = IpingDashboardDefaultEditor(
      all: all,
      defaultIds: defaultIds,
      saved: const [],
    );

    expect(_ids(editor.cards), defaultIds);
    expect(_ids(editor.available), ['memory']);
    expect(_ids(editor.desktopCards), _ids(all));
  });

  test('keeps the saved order and visibility, ignoring unknown ids', () {
    final editor = IpingDashboardDefaultEditor(
      all: all,
      defaultIds: defaultIds,
      saved: const ['memory', 'missing', 'status'],
    );

    expect(_ids(editor.cards), ['memory', 'status']);
    expect(_ids(editor.available), ['speed', 'mode']);
  });

  test('falls back to the default cards when nothing saved is known', () {
    final editor = IpingDashboardDefaultEditor(
      all: all,
      defaultIds: defaultIds,
      saved: const ['missing'],
    );

    expect(_ids(editor.cards), defaultIds);
  });

  test('saves changes and resets to the default arrangement', () {
    final saved = <List<String>>[];
    final editor = IpingDashboardDefaultEditor(
      all: all,
      defaultIds: defaultIds,
      saved: const [],
      onSave: saved.add,
    );

    editor.save(const ['status', 'memory']);
    editor.reset();

    expect(saved, [
      ['status', 'memory'],
      defaultIds,
    ]);
  });
}
