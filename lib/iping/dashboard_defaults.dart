import 'package:flutter/foundation.dart';

import 'dashboard_host.dart';

class IpingDashboardDefaultEditor implements IpingDashboardEditor {
  IpingDashboardDefaultEditor({
    required List<IpingDashboardCard> all,
    required this.defaultIds,
    required List<String> saved,
    this.onSave,
  }) : _all = List.unmodifiable(all),
       _cards = _arranged(all, defaultIds, saved);

  final List<IpingDashboardCard> _all;
  final List<String> defaultIds;

  final ValueChanged<List<String>>? onSave;
  final List<IpingDashboardCard> _cards;

  static List<IpingDashboardCard> _arranged(
    List<IpingDashboardCard> all,
    List<String> defaultIds,
    List<String> saved,
  ) {
    final byId = {for (final card in all) card.id: card};
    final ids = saved.isEmpty ? defaultIds : saved;
    final seen = <String>{};
    final cards = [
      for (final id in ids)
        if (seen.add(id)) ?byId[id],
    ];
    return cards.isEmpty ? [for (final id in defaultIds) ?byId[id]] : cards;
  }

  @override
  List<IpingDashboardCard> get cards => _cards;

  @override
  List<IpingDashboardCard> get available => [
    for (final card in _all)
      if (!_cards.contains(card)) card,
  ];

  @override
  List<IpingDashboardCard> get desktopCards => _all;

  @override
  void save(List<String> ids) => onSave?.call(ids);

  @override
  void reset() => onSave?.call(defaultIds);
}
