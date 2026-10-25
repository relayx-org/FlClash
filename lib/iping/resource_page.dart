import 'dart:async';

import 'package:fl_clash/features/form/list_editor_view.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'filters_page.dart';
import 'resource_controller.dart';

typedef IpingResourceEditor<T, K> =
    Widget Function(
      BuildContext context,
      T? item,
      IpingResourceController<T, K> controller,
    );

typedef IpingResourceItemBuilder<T> =
    Widget Function(
      BuildContext context,
      T item,
      int index,
      bool editing,
      bool selected,
      VoidCallback toggle,
      VoidCallback edit,
    );

class IpingResourcePage<T, K> extends StatefulWidget {
  const IpingResourcePage({
    super.key,
    required this.title,
    required this.store,
    required this.keyOf,
    required this.nameOf,
    required this.subtitleOf,
    required this.editor,
    this.description,
    this.actionBuilder,
    this.menuItemsOf,
    this.addMenuItems = const [],
    this.itemBuilder,
    this.addMenuBuilder,
    this.menuBuilder,
  });

  final String title;
  final String? description;
  final IpingResourceStore<T> store;
  final K Function(T) keyOf;
  final String Function(T) nameOf;
  final String Function(T) subtitleOf;
  final IpingResourceEditor<T, K> editor;
  final List<IconButtonData> Function(IpingResourceController<T, K>)?
  actionBuilder;
  final List<CommonPopupMenuItem> Function(T)? menuItemsOf;
  final List<CommonPopupMenuItem> addMenuItems;
  final IpingResourceItemBuilder<T>? itemBuilder;
  final List<CommonPopupMenuItem> Function(IpingResourceController<T, K>)?
  addMenuBuilder;
  final List<CommonPopupMenuItem> Function(T, IpingResourceController<T, K>)?
  menuBuilder;

  @override
  State<IpingResourcePage<T, K>> createState() =>
      _IpingResourcePageState<T, K>();
}

class _IpingResourcePageState<T, K> extends State<IpingResourcePage<T, K>> {
  late final _controller = IpingResourceController<T, K>(
    widget.store,
    keyOf: widget.keyOf,
  );
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit([T? item]) async {
    if (_controller.busy) return;
    setState(() => _editing = true);
    try {
      await showFormSheet<void>(
        context: context,
        builder: (context) => widget.editor(context, item, _controller),
      );
    } finally {
      _controller.cancelPending();
      _controller.clearError();
      if (mounted) {
        setState(() => _editing = false);
        if (!_controller.busy) unawaited(_controller.load());
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      return ListEditorView<T, K>(
        title: widget.title,
        description: widget.description,
        items: _controller.items,
        busy: _controller.busy,
        extraActions: widget.actionBuilder?.call(_controller) ?? const [],
        menuItemsOf: widget.menuBuilder == null && widget.menuItemsOf == null
            ? null
            : (item) => [
                CommonPopupMenuItem(
                  glyph: AppGlyphs.compose,
                  label: l.edit,
                  onPressed: _controller.busy ? null : () => _edit(item),
                ),
                CommonPopupMenuItem(
                  glyph: AppGlyphs.delete,
                  label: l.delete,
                  onPressed: _controller.busy
                      ? null
                      : () async {
                          if (await confirmListEditorDelete(
                                context,
                                widget.title,
                              ) &&
                              mounted) {
                            await _controller.remove({widget.keyOf(item)});
                          }
                        },
                ),
                ...?widget.menuBuilder?.call(item, _controller) ??
                    widget.menuItemsOf?.call(item),
              ],
        addMenuItems:
            widget.addMenuBuilder?.call(_controller) ?? widget.addMenuItems,
        error: _editing || _controller.error == null
            ? null
            : resourceErrorMessage(_controller.error, l, label: widget.title),
        onRetry: () => _controller.load(),
        idOf: widget.keyOf,
        itemBuilder: (context, item, index, editing, selected, toggle) =>
            widget.itemBuilder?.call(
              context,
              item,
              index,
              editing,
              selected,
              toggle,
              () => _edit(item),
            ) ??
            DecorationListItem(
              isSelected: selected,
              onPressed: editing ? toggle : () => _edit(item),
              contentPadding: const EdgeInsets.only(left: 16),
              title: Text(
                widget.nameOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                widget.subtitleOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: CommonCheckBox(
                value: selected,
                isCircle: true,
                onChanged: (_) => toggle(),
              ),
            ),
        onReorder: (oldIndex, newIndex) async {
          await _controller.reorder(oldIndex, newIndex);
        },
        onAdd: _edit,
        onDelete: _controller.remove,
        confirmDelete: () => confirmListEditorDelete(context, widget.title),
        searchFieldsOf: (item) => [
          widget.nameOf(item),
          widget.subtitleOf(item),
        ],
        emptyLabel: l.nullTip(widget.title),
      );
    },
  );
}
