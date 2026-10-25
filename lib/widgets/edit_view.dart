part of 'input.dart';

/// Public for `MapEditView`, whose entries are entered in a form.
abstract class EditViewState<W extends StatefulWidget, T> extends State<W> {
  List<T> _entries = [];
  late final List<T> _initialEntries;
  Set<String> _selected = {};
  bool _routeTakesResult = false;

  String get title;

  List<T> get initialEntries;

  String idOf(T entry);

  Widget buildTitle(T entry);

  Widget? buildSubtitle(T entry);

  bool sameEntries(List<T> a, List<T> b);

  Object popResult(List<T> entries);

  @protected
  List<T> get entries => _entries;

  /// Adds when [entry] is null and edits it otherwise; an add may return
  /// several entries from batch mode.
  Future<List<T>?> showEntryEditor(T? entry);

  @override
  void initState() {
    super.initState();
    _entries = List<T>.from(initialEntries);
    _initialEntries = List<T>.from(_entries);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _routeTakesResult = route is DragBackRouteMixin;
    if (route is DragBackRouteMixin) {
      route.pageResult = () => popResult(_entries);
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    _entries = List<T>.from(_entries);
    _entries.insert(newIndex, _entries.removeAt(oldIndex));
    setState(() {});
  }

  void _handleSelected(T entry) {
    setState(() {
      final id = idOf(entry);
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _handleSelectAll() {
    final ids = _entries.map(idOf).toSet();
    setState(() => _selected = _selected.containsAll(ids) ? {} : ids);
  }

  Future<void> _handleAdd() async {
    final entries = await showEntryEditor(null);
    if (!mounted || entries == null || entries.isEmpty) return;
    _entries = [..._entries, ...entries];
    setState(() {});
  }

  Future<void> _handleEdit(T entry) async {
    final entries = await showEntryEditor(entry);
    if (!mounted || entries == null || entries.isEmpty) return;
    final next = entries.single;
    final id = idOf(entry);
    _entries = [
      for (final current in _entries)
        if (idOf(current) == id) next else current,
    ];
    setState(() {});
  }

  Future<void> _handleDelete() async {
    final res = await confirmChange(
      context,
      message: AppLocalizations.of(context).deleteMultipTip(title),
      destructive: true,
      confirmText: AppLocalizations.of(context).delete,
    );
    if (res != true || !mounted) {
      return;
    }
    final selected = _selected;
    _entries = _entries
        .where((entry) => !selected.contains(idOf(entry)))
        .toList();
    setState(() => _selected = {});
    setState(() {});
  }

  Future<void> _handleReset() async {
    final res = await confirmChange(
      context,
      message: AppLocalizations.of(context).resetPageChangesTip,
      destructive: true,
      confirmText: AppLocalizations.of(context).reset,
    );
    if (!mounted || res != true) {
      return;
    }
    _entries = _initialEntries;
    setState(() {});
  }

  Widget _buildEntry({
    required T entry,
    required int index,
    required int length,
    required bool isSelected,
    required bool isEditing,
  }) {
    final position = ItemPosition.get(index, length);
    return ReorderableDelayedDragStartListener(
      key: ValueKey(idOf(entry)),
      index: index,
      child: ItemPositionProvider(
        position: position,
        child: SelectedDecorationListItem(
          title: buildTitle(entry),
          subtitle: buildSubtitle(entry),
          isSelected: isSelected,
          isEditing: isEditing,
          onSelected: () {
            _handleSelected(entry);
          },
          onPressed: () {
            _handleEdit(entry);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final selected = _selected;
    final isEditing = selected.isNotEmpty;
    return CommonPopScope(
      onPop: isEditing
          ? (_) {
              setState(() => _selected = {});
              return false;
            }
          : _routeTakesResult
          ? null
          : (_) {
              Navigator.of(context).pop(popResult(_entries));
              return false;
            },
      child: CommonScaffold(
        title: title,
        selectionActions: [
          if (isEditing) ...[
            IconButtonData(
              glyph: AppGlyphs.delete,
              tooltip: appLocalizations.delete,
              onPressed: _handleDelete,
            ),
            IconButtonData(
              glyph: AppGlyphs.selectAll,
              tooltip: appLocalizations.selectAll,
              onPressed: _handleSelectAll,
            ),
          ],
        ],
        iconActions: [
          if (!isEditing) ...[
            if (!sameEntries(_entries, _initialEntries))
              IconButtonData(
                glyph: AppGlyphs.reset,
                tooltip: appLocalizations.reset,
                onPressed: _handleReset,
              ),
            IconButtonData(
              glyph: AppGlyphs.addCircle,
              tooltip: appLocalizations.add,
              onPressed: _handleAdd,
            ),
          ],
        ],
        body: NullStatusSwitcher(
          isEmpty: _entries.isEmpty,
          nullStatus: NullStatus(label: appLocalizations.noData),
          child: ReorderableListView.builder(
            padding: EdgeInsets.only(
              bottom: 16 + 64,
              top: context.contentTopPadding,
              left: 16,
              right: 16,
            ),
            buildDefaultDragHandles: false,
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return _buildEntry(
                entry: entry,
                index: index,
                length: _entries.length,
                isSelected: selected.contains(idOf(entry)),
                isEditing: isEditing,
              );
            },
            proxyDecorator: (child, index, animation) {
              final entry = _entries[index];
              return commonProxyDecorator(
                _buildEntry(
                  entry: entry,
                  index: index,
                  length: _entries.length,
                  isSelected: selected.contains(idOf(entry)),
                  isEditing: isEditing,
                ),
                index,
                animation,
              );
            },
            onReorderItem: _handleReorder,
          ),
        ),
      ),
    );
  }
}

class ListEditView extends StatefulWidget {
  final String title;
  final List<String> items;
  final Widget Function(String item) titleBuilder;
  final int? itemMaxLength;
  final bool multiline;
  final String? Function(String item)? itemValidator;

  const ListEditView({
    super.key,
    required this.title,
    required this.items,
    required this.titleBuilder,
    this.itemMaxLength,
    this.multiline = false,
    this.itemValidator,
  });

  @override
  State<ListEditView> createState() => _ListEditViewState();
}

class _ListEditViewState extends EditViewState<ListEditView, String> {
  @override
  String get title => widget.title;

  @override
  List<String> get initialEntries => widget.items;

  @override
  String idOf(String entry) => entry;

  @override
  Widget buildTitle(String entry) => widget.titleBuilder(entry);

  @override
  Widget? buildSubtitle(String entry) {
    if (widget.itemValidator?.call(entry) case final error?) {
      return Text(error, style: TextStyle(color: context.colorScheme.error));
    }
    return null;
  }

  @override
  bool sameEntries(List<String> a, List<String> b) =>
      const ListEquality<String>().equals(a, b);

  @override
  Object popResult(List<String> entries) => entries;

  @override
  Future<List<String>?> showEntryEditor(String? entry) {
    return showListEntryDialog(
      context,
      title: widget.title,
      entries: _entries,
      entry: entry,
      itemMaxLength: widget.itemMaxLength,
      multiline: widget.multiline,
      itemValidator: widget.itemValidator,
    );
  }
}

Future<List<String>?> showListEntryDialog(
  BuildContext context, {
  required String title,
  required List<String> entries,
  String? entry,
  String? valueLabel,
  int? itemMaxLength,
  bool multiline = false,
  String? Function(String item)? itemValidator,
}) {
  final appLocalizations = AppLocalizations.of(context);
  final label = valueLabel ?? appLocalizations.value;

  String? validator(String? value) {
    final parsed = multiline
        ? ParsedInput(
            entries: [
              if (value != null && value.trim().isNotEmpty) value.trim(),
            ],
            skippedExisting: 0,
            issues: [
              if (itemMaxLength != null && (value?.length ?? 0) > itemMaxLength)
                InputIssue(
                  line: 1,
                  raw: value!,
                  kind: InputIssueKind.valueTooLong,
                ),
            ],
          )
        : parseListInput(value ?? '', maxLength: itemMaxLength);
    if (!parsed.isValid) {
      return appLocalizations.maxLengthTip(label, itemMaxLength!);
    }
    if (parsed.entries.isEmpty) {
      return appLocalizations.emptyTip(label);
    }
    if (parsed.entries.length > 1) {
      return appLocalizations.singleValueTip(label);
    }
    final next = parsed.entries.single;
    if (next != entry && entries.contains(next)) {
      return appLocalizations.existsTip(label);
    }
    return itemValidator?.call(next);
  }

  return showFloatingDialog<List<String>>(
    context: context,
    child: EntryDialog<String>(
      title: entry == null ? appLocalizations.add : appLocalizations.edit,
      valueField: Field(label: label, value: entry ?? '', validator: validator),
      valueMaxLength: itemMaxLength,
      toEntry: (value) =>
          multiline ? value.trim() : parseListInput(value).entries.single,
      batch: entry != null || multiline
          ? null
          : BatchInput(
              label: title,
              formatTip: appLocalizations.batchListInputTip,
              parse: (text) => parseListInput(
                text,
                existing: entries.toSet(),
                maxLength: itemMaxLength,
                isValid: itemValidator == null
                    ? null
                    : (item) => itemValidator(item) == null,
              ),
              issueMessage: (issue) => switch (issue.kind) {
                InputIssueKind.invalidValue => itemValidator!(issue.raw)!,
                _ => appLocalizations.maxLengthTip(label, itemMaxLength!),
              },
            ),
    ),
  );
}
