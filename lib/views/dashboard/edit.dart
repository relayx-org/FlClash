import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/iping/widgets/dashboard_card_editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_registry.dart';

/// Adapts the app's [DashboardWidget] setting to the shared card editor.
class DashboardEditor extends ConsumerWidget {
  const DashboardEditor({
    super.key,
    required this.platform,
    required this.widgets,
    required this.cardKeyOf,
    required this.padding,
    required this.gap,
    required this.onDone,
  });

  final SupportPlatform platform;
  final List<DashboardWidget> widgets;

  /// Shared with the cards outside edit mode, so each keeps its state.
  final GlobalKey Function(DashboardWidget widget) cardKeyOf;
  final EdgeInsets padding;
  final double gap;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = [for (final widget in widgets) _cardOf(widget)];
    final available = [
      for (final widget in DashboardWidget.values)
        if (widget.platforms.contains(platform) && !widgets.contains(widget))
          _cardOf(widget),
    ];
    return IpingDashboardCardEditor(
      cards: cards,
      available: available,
      cardKeyOf: (id) => cardKeyOf(DashboardWidget.values.byName(id)),
      padding: padding,
      gap: gap,
      onDone: onDone,
      dragsAtOnce: desktopPlatforms.contains(platform),
      onSave: (ids) => _save(ref, ids),
    );
  }

  IpingDashboardCard _cardOf(DashboardWidget widget) => IpingDashboardCard(
    id: widget.name,
    label: (context) => widget.label(context),
    description: (context) => widget.description(context),
    glyph: widget.glyph,
    removable: widget.removable,
    builder: (_) => widget.card,
  );

  void _save(WidgetRef ref, List<String> ids) {
    final byName = DashboardWidget.values.asNameMap();
    final shown = [for (final id in ids) byName[id]].nonNulls.toList();
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            dashboardWidgets: _keepingOtherPlatforms(
              state.dashboardWidgets,
              shown,
            ),
          ),
        );
  }

  /// Cards this platform cannot show stay where they were among the rest.
  List<DashboardWidget> _keepingOtherPlatforms(
    List<DashboardWidget> saved,
    List<DashboardWidget> shown,
  ) {
    final result = [...shown];
    var at = 0;
    for (final card in saved) {
      if (card.platforms.contains(platform)) {
        final index = result.indexOf(card);
        if (index != -1) at = index + 1;
      } else {
        result.insert(at++, card);
      }
    }
    return result;
  }
}
