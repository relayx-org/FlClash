import 'package:fl_clash/common/common.dart';
import 'list_editor_view.dart';
export 'list_editor_view.dart' show ListEditorAddAction;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ListEditorItemBuilder<T> =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      T item,
      int index,
      bool isEditing,
      bool isSelected,
      VoidCallback onToggleSelected,
    );

class ListEditorPage<T, K> extends ConsumerStatefulWidget {
  final String title;
  final List<T>? Function(WidgetRef ref) itemsOf;
  final ListEditorItemBuilder<T> itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;
  final VoidCallback? onQuickEdit;
  final List<CommonPopupMenuItem> addMenuItems;
  final String emptyLabel;
  final double? itemExtent;
  final K Function(T item) idOf;
  final void Function(Set<K> ids)? onDelete;
  final Iterable<String?> Function(T item)? searchFieldsOf;
  final List<CommonPopupMenuItem> Function(T item)? menuItemsOf;

  const ListEditorPage({
    super.key,
    required this.title,
    required this.itemsOf,
    required this.itemBuilder,
    required this.onReorder,
    required this.onAdd,
    this.onQuickEdit,
    this.addMenuItems = const [],
    required this.emptyLabel,
    this.itemExtent,
    required this.idOf,
    this.onDelete,
    this.searchFieldsOf,
    this.menuItemsOf,
  });

  @override
  ConsumerState<ListEditorPage<T, K>> createState() =>
      _ListEditorPageState<T, K>();
}

class _ListEditorPageState<T, K> extends ConsumerState<ListEditorPage<T, K>> {
  @override
  Widget build(BuildContext context) => ListEditorView<T, K>(
    title: widget.title,
    items: widget.itemsOf(ref),
    itemBuilder: (context, item, index, editing, selected, toggle) => widget
        .itemBuilder(context, ref, item, index, editing, selected, toggle),
    onReorder: (oldIndex, newIndex) {
      widget.onReorder(oldIndex, newIndex);
      if (mounted) setState(() {});
    },
    onAdd: widget.onAdd,
    onQuickEdit: widget.onQuickEdit,
    addMenuItems: widget.addMenuItems,
    emptyLabel: widget.emptyLabel,
    itemExtent: widget.itemExtent,
    idOf: widget.idOf,
    onDelete: widget.onDelete == null
        ? null
        : (ids) {
            widget.onDelete!(ids);
            if (mounted) setState(() {});
            return true;
          },
    searchFieldsOf: widget.searchFieldsOf,
    menuItemsOf: widget.menuItemsOf,
    confirmDelete: () async =>
        await dialogs.showMessage(
          message: TextSpan(
            text: context.appLocalizations.deleteMultipTip(widget.title),
          ),
          destructive: true,
          confirmText: context.appLocalizations.delete,
        ) ==
        true,
  );
}
