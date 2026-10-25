import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'selection_sheet_view.dart';
export 'selection_sheet_view.dart' show SelectionSection;

class SelectionSheet<T> extends ConsumerWidget {
  final String title;
  final List<SelectionSection<T>> sections;
  final String Function(T item) labelBuilder;
  final Widget Function(T item, Widget title)? titleBuilder;
  final T? Function(WidgetRef ref) selectedOf;
  final ValueChanged<T> onSelected;
  final String? emptyLabel;
  final NullStatus? loadingStatus;

  /// A picked item collapses out instead of the sheet closing, which it does
  /// once the last item is picked.
  final bool removeOnSelect;

  const SelectionSheet({
    super.key,
    required this.title,
    required this.sections,
    required this.labelBuilder,
    this.titleBuilder,
    required this.selectedOf,
    required this.onSelected,
    this.emptyLabel,
    this.loadingStatus,
    this.removeOnSelect = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => SelectionSheetView<T>(
    title: title,
    sections: sections,
    labelBuilder: labelBuilder,
    titleBuilder: titleBuilder,
    selected: selectedOf(ref),
    onSelected: onSelected,
    emptyLabel: emptyLabel,
    loadingStatus: loadingStatus,
    removeOnSelect: removeOnSelect,
  );
}
