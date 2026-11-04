import 'dart:async';

import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/common/iterable.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

List<String> _visibleUserAgents(List<String> saved, String? selected) =>
    {...saved, ?selected}.toList();

class UserAgentsPage extends StatefulWidget {
  const UserAgentsPage({
    super.key,
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.onSelected,
  });

  final List<String> entries;
  final String? selected;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String?> onSelected;

  @override
  State<UserAgentsPage> createState() => _UserAgentsPageState();
}

class _UserAgentsPageState extends State<UserAgentsPage> {
  late List<String> _saved = widget.entries;
  late List<String> _entries = _visibleUserAgents(_saved, widget.selected);
  late String? _selected = widget.selected;

  @override
  void didUpdateWidget(covariant UserAgentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.entries, oldWidget.entries)) {
      _saved = widget.entries;
      _entries = _visibleUserAgents(_saved, _selected);
    }
    if (widget.selected != oldWidget.selected) {
      _selected = widget.selected;
      _entries = _visibleUserAgents(_saved, _selected);
    }
  }

  void _apply(
    List<String> userAgents,
    String? selected, {
    bool persistList = true,
    bool selectionChanged = false,
  }) {
    setState(() {
      _saved = userAgents;
      _selected = selected;
      _entries = _visibleUserAgents(_saved, _selected);
    });
    if (persistList) {
      widget.onChanged(_entries);
    }
    if (selectionChanged) {
      widget.onSelected(selected);
    }
  }

  void _save(List<String> userAgents) => _apply(userAgents, _selected);

  void _select(String? userAgent) =>
      _apply(_saved, userAgent, persistList: false, selectionChanged: true);

  Future<String?> _showInputDialog([String? userAgent]) async {
    final appLocalizations = AppLocalizations.of(context);
    final entries = _entries;
    final res = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: userAgent == null ? appLocalizations.add : appLocalizations.edit,
        value: userAgent ?? '',
        labelText: appLocalizations.userAgent,
        inputFormatters: [
          FilteringTextInputFormatter.singleLineFormatter,
          ...TextInputLimits.limit(TextInputLimits.userAgent),
        ],
        validator: (value) {
          final next = value?.trim() ?? '';
          if (next.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.userAgent);
          }
          if (next != userAgent && entries.contains(next)) {
            return appLocalizations.existsTip(appLocalizations.userAgent);
          }
          return null;
        },
      ),
    );
    return res?.trim();
  }

  Future<void> _handleAdd() async {
    final userAgent = await _showInputDialog();
    if (!mounted || userAgent == null) {
      return;
    }
    _save([..._saved, userAgent]);
  }

  Future<void> _handleEdit(String userAgent) async {
    final next = await _showInputDialog(userAgent);
    if (!mounted || next == null || next == userAgent) {
      return;
    }
    final nextSelected = _selected == userAgent ? next : _selected;
    _apply(
      [for (final item in _saved) item == userAgent ? next : item],
      nextSelected,
      selectionChanged: nextSelected != _selected,
    );
  }

  Future<void> _handleDelete(String userAgent) async {
    final appLocalizations = AppLocalizations.of(context);
    final res = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => CommonDialog(
          title: appLocalizations.tip,
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(appLocalizations.delete),
            ),
          ],
          child: SelectableText(
            appLocalizations.deleteTip(appLocalizations.userAgent),
          ),
        ),
      ),
    );
    if (!mounted || res != true) {
      return;
    }
    final nextSelected = _selected == userAgent ? null : _selected;
    _apply(
      [..._saved]..remove(userAgent),
      nextSelected,
      selectionChanged: nextSelected != _selected,
    );
  }

  List<CommonPopupMenuItem> _buildMenuItems(String userAgent) {
    final appLocalizations = AppLocalizations.of(context);
    return [
      CommonPopupMenuItem(
        glyph: AppGlyphs.edit,
        label: appLocalizations.edit,
        onPressed: () {
          unawaited(_handleEdit(userAgent));
        },
      ),
      CommonPopupMenuItem(
        danger: true,
        glyph: AppGlyphs.delete,
        label: appLocalizations.delete,
        onPressed: () {
          unawaited(_handleDelete(userAgent));
        },
      ),
    ];
  }

  Widget _buildItem(List<String> entries, int index, String? selected) {
    final appLocalizations = AppLocalizations.of(context);
    final userAgent = entries[index];
    return SortableItem(
      key: ValueKey(userAgent),
      index: index,
      child: ContextMenuRegion(
        menuItems: _buildMenuItems(userAgent),
        child: ItemPositionProvider(
          position: ItemPosition.get(index + 1, entries.length + 1),
          child: _UserAgentItem(
            label: userAgent,
            isSelected: userAgent == selected,
            onSelected: () => _select(userAgent),
            trailing: DetailButton(
              glyph: AppGlyphs.edit,
              tooltip: appLocalizations.edit,
              onPressed: () {
                unawaited(_handleEdit(userAgent));
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final entries = _entries;
    final selectedUa = _selected;
    return CommonScaffold(
      canSort: entries.length > 1,
      title: appLocalizations.userAgent,
      actions: [
        IconButton(
          tooltip: appLocalizations.add,
          onPressed: _handleAdd,
          icon: const GlyphIcon(AppGlyphs.addCircle),
        ),
      ],
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(
          16,
        ).copyWith(top: context.contentTopPadding),
        buildDefaultDragHandles: false,
        header: ItemPositionProvider(
          position: ItemPosition.get(0, entries.length + 1),
          child: _UserAgentItem(
            label: appLocalizations.defaultText,
            isSelected: selectedUa == null,
            onSelected: () => _select(null),
          ),
        ),
        itemCount: entries.length,
        itemBuilder: (_, index) => _buildItem(entries, index, selectedUa),
        proxyDecorator: (_, index, animation) {
          return commonProxyDecorator(
            _buildItem(entries, index, selectedUa),
            index,
            animation,
          );
        },
        onReorderItem: (oldIndex, newIndex) {
          _save(entries.copyAndReorder(oldIndex, newIndex));
        },
      ),
    );
  }
}

class _UserAgentItem extends StatelessWidget {
  const _UserAgentItem({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.trailing,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      isSelected: isSelected,
      horizontalTitleGap: 8,
      contentPadding: EdgeInsets.only(
        left: 14,
        right: SortableItem.maybeOf(context) == null ? 16 : 0,
      ),
      leading: SizedBox.square(
        dimension: 24,
        child: isSelected ? const Center(child: SelectionCheck()) : null,
      ),
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onPressed: onSelected,
    );
  }
}
