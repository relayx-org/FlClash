import 'dart:async';

import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/filter_text.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/features/form/list_editor_view.dart';
import 'package:fl_clash/iping/backend_resources.dart';
import 'package:fl_clash/iping/resource_controller.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

String resourceErrorMessage(
  Object? error,
  AppLocalizations l, {
  String? label,
}) => switch (error) {
  IpingResourceException(issue: IpingResourceIssue.duplicate) => l.existsTip(
    l.label,
  ),
  IpingResourceException(issue: IpingResourceIssue.missing) =>
    l.resourceChangedTip,
  IpingResourceException(issue: IpingResourceIssue.unavailable) =>
    l.ipingNetworkError,
  IpingResourceException(message: final String message) => message,
  IpingResourceException() => l.invalidSettingTip(label ?? l.filters),
  _ => error?.toString() ?? l.ipingStorageError,
};

class IpingFiltersPage extends StatefulWidget {
  const IpingFiltersPage({super.key, required this.store, this.description});
  final IpingResourceStore<Filter> store;
  final String? description;

  @override
  State<IpingFiltersPage> createState() => _IpingFiltersPageState();
}

class _IpingFiltersPageState extends State<IpingFiltersPage> {
  late final _controller = IpingResourceController<Filter, String>(
    widget.store,
    keyOf: (filter) => filter.label,
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

  Future<void> _edit([Filter? filter]) async {
    if (_controller.busy) return;
    setState(() => _editing = true);
    try {
      await showFormSheet<void>(
        context: context,
        builder: (_) => _FilterForm(
          filter: filter,
          reservedLabels: {
            for (final item in _controller.items ?? <Filter>[])
              if (item.label != filter?.label) item.label,
          },
          save: (value) => _controller.put(value, replacing: filter?.label),
          errorOf: () => _controller.error,
        ),
      );
    } finally {
      _controller.cancelPending();
      _controller.clearError();
      if (mounted) setState(() => _editing = false);
      if (mounted && !_controller.busy) unawaited(_controller.load());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      return ListEditorView<Filter, String>(
        title: l.filters,
        description: widget.description,
        items: _controller.items,
        busy: _controller.busy,
        error: _editing || _controller.error == null
            ? null
            : resourceErrorMessage(_controller.error, l),
        onRetry: () => _controller.load(),
        idOf: (item) => item.label,
        itemBuilder: (context, item, index, editing, selected, toggle) =>
            _FilterItem(
              filter: item,
              isEditing: editing,
              isSelected: selected,
              onSelected: toggle,
              onPressed: () => _edit(item),
            ),
        onReorder: (oldIndex, newIndex) async {
          await _controller.reorder(oldIndex, newIndex);
        },
        onAdd: _edit,
        onDelete: _controller.remove,
        confirmDelete: () => confirmListEditorDelete(
          context,
          AppLocalizations.of(context).filters,
        ),
        searchFieldsOf: (item) => [item.label, item.regex],
        emptyLabel: l.nullTip(l.filters),
      );
    },
  );
}

class _FilterItem extends StatelessWidget {
  final Filter filter;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onPressed;

  const _FilterItem({
    required this.filter,
    required this.isEditing,
    required this.isSelected,
    required this.onSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      isSelected: isSelected,
      onPressed: isEditing ? onSelected : onPressed,
      contentPadding: const EdgeInsets.only(left: 16),
      title: TooltipText(
        text: Text(filter.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      subtitle: FilterRegexText(filter.regex),
      trailing: CommonCheckBox(
        value: isSelected,
        isCircle: true,
        onChanged: (_) => onSelected(),
      ),
    );
  }
}

enum _FilterField { label, regex }

class _FilterForm extends StatefulWidget {
  final Filter? filter;
  final Future<bool> Function(Filter value) save;
  final Object? Function() errorOf;
  final Set<String> reservedLabels;

  const _FilterForm({
    required this.filter,
    required this.save,
    required this.errorOf,
    required this.reservedLabels,
  });

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  late final TextEditingController _labelController;
  late final TextEditingController _regexController;
  String? _regexError;
  String? _saveError;
  bool _checking = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.filter?.label);
    _regexController = TextEditingController(text: widget.filter?.regex);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _regexController.dispose();
    super.dispose();
  }

  ({_FilterField field, String message})? _issue() {
    final appLocalizations = AppLocalizations.of(context);
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      return (
        field: _FilterField.label,
        message: appLocalizations.emptyTip(appLocalizations.label),
      );
    }
    if (widget.reservedLabels.contains(label)) {
      return (
        field: _FilterField.label,
        message: appLocalizations.existsTip(appLocalizations.label),
      );
    }
    if (_regexController.text.trim().isEmpty) {
      return (
        field: _FilterField.regex,
        message: appLocalizations.emptyTip(appLocalizations.regex),
      );
    }
    if (_regexError case final error?) {
      return (field: _FilterField.regex, message: error);
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_checking) {
      return;
    }
    if (_issue() != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    final filter = Filter(
      label: _labelController.text.trim(),
      regex: _regexController.text.trim(),
    );
    setState(() {
      _checking = true;
      _saveError = null;
    });
    var saved = false;
    try {
      saved = await widget.save(filter);
      if (!mounted) return;
      final error = widget.errorOf();
      if (error is IpingResourceException &&
          error.issue == IpingResourceIssue.invalid &&
          error.message != null) {
        _regexError = error.message;
      } else if (!saved) {
        _saveError = resourceErrorMessage(error, AppLocalizations.of(context));
      }
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _attempted = true;
        });
      }
    }
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final issue = _attempted ? _issue() : null;
    return FormPage(
      title: widget.filter == null
          ? appLocalizations.add
          : appLocalizations.edit,
      onSave: _handleSubmit,
      saving: _checking,
      error: issue?.message ?? _saveError,
      children: [
        generateSection(
          items: [
            FormRow(
              title: appLocalizations.label,
              invalid: issue?.field == _FilterField.label,
              trailing: FormRowTextField(
                controller: _labelController,
                autofocus: widget.filter == null,
                hintText: appLocalizations.required,
                textInputAction: TextInputAction.next,
                inputFormatters: TextInputLimits.limit(TextInputLimits.name),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
              ),
            ),
            FormRow(
              title: appLocalizations.regex,
              invalid: issue?.field == _FilterField.regex,
              trailing: FormRowTextField(
                controller: _regexController,
                hintText: r'(?i)hk|hong\s*kong',
                autocorrect: false,
                textInputAction: TextInputAction.done,
                inputFormatters: TextInputLimits.limit(TextInputLimits.filter),
                onChanged: (_) {
                  if (_attempted || _regexError != null) {
                    setState(() {
                      _regexError = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => _handleSubmit(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
