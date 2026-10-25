import 'dart:async';

import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/common/iterable.dart';
import 'package:fl_clash/models/custom_proxy.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:material_ui/material_ui.dart';

import 'form_row.dart';
import 'proxy_field.dart';
import 'selection_sheet_view.dart';
import 'list_editor_view.dart';

class IpingCustomProxyEditor extends StatefulWidget {
  const IpingCustomProxyEditor({
    super.key,
    required this.proxy,
    required this.isNew,
    required this.onChanged,
    required this.validate,
    required this.save,
    required this.close,
    required this.issuesBuilder,
    this.nameInvalid = false,
    this.delete,
    this.quickEdit,
    this.bindSave,
    this.showSaveProgress = true,
  });

  final CustomProxy proxy;
  final bool isNew;
  final ValueChanged<CustomProxy> onChanged;
  final Future<String?> Function(CustomProxy) validate;
  final Future<bool> Function(ValueChanged<String> onRejected) save;
  final bool showSaveProgress;
  final VoidCallback close;
  final bool nameInvalid;
  final Widget Function(BuildContext, String?, bool) issuesBuilder;
  final Future<bool> Function()? delete;
  final Future<Map<String, dynamic>?> Function(CustomProxy)? quickEdit;
  final ValueChanged<Future<void> Function()>? bindSave;

  @override
  State<IpingCustomProxyEditor> createState() => _IpingCustomProxyEditorState();
}

class _IpingCustomProxyEditorState extends State<IpingCustomProxyEditor> {
  static const _validateDelay = Duration(milliseconds: 400);

  late final bool _isNew;
  late CustomProxy _proxy;
  Timer? _validateTimer;
  int _validateRequest = 0;
  String? _coreError;
  bool _saving = false;
  bool _submitted = false;
  var _revealed = <String>{};
  late Set<ProxyField> _shown;

  /// Added options not given a value since, the only ones a save keeps empty.
  late Set<ProxyField> _untouched;

  /// Bumped when the whole mapping is replaced, so the fields drop the text
  /// they were initialized with.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _proxy = widget.proxy;
    final proxy = _proxy;
    _isNew = widget.isNew;
    _shown = _shownIn(proxy);
    _untouched = {
      for (final field in proxy.emptyOptions)
        if (proxy.valueOf(field) == null) field,
    };
    widget.bindSave?.call(_handleSave);
    _scheduleValidate();
  }

  @override
  void didUpdateWidget(covariant IpingCustomProxyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.proxy, widget.proxy)) {
      _proxy = widget.proxy;
      _untouched.removeWhere((field) => _proxy.valueOf(field) != null);
      _scheduleValidate();
    }
  }

  void _change(CustomProxy proxy) {
    setState(() => _proxy = proxy);
    widget.onChanged(proxy);
    _scheduleValidate();
  }

  @override
  void dispose() {
    _validateTimer?.cancel();
    super.dispose();
  }

  void _scheduleValidate() {
    _validateRequest++;
    _coreError = null;
    _validateTimer?.cancel();
    _validateTimer = Timer(_validateDelay, _validate);
  }

  Future<void> _handleQuickEdit() async {
    final definition = await widget.quickEdit?.call(_proxy);
    if (definition == null || !mounted) return;
    final next = _proxy.copyWith(definition: definition);
    _syncShown(next);
    setState(() => _revision++);
  }

  static Set<ProxyField> _shownIn(CustomProxy proxy) => {
    for (final field in proxy.options)
      if (proxy.valueOf(field) != null || proxy.emptyOptions.contains(field))
        field,
  };

  CustomProxy _withShown(CustomProxy proxy, Set<ProxyField> shown) =>
      proxy.copyWith(
        emptyOptions: {
          for (final field in shown)
            if (proxy.valueOf(field) == null && _untouched.contains(field))
              field,
        },
      );

  /// Keeps a row for every option [proxy] offers that has a value, was shown,
  /// or was [unlocked] by the change that led to [proxy].
  void _syncShown(
    CustomProxy proxy, {
    Iterable<ProxyField> unlocked = const [],
  }) {
    final shown = {
      for (final field in proxy.options)
        if (_shown.contains(field) ||
            unlocked.contains(field) ||
            proxy.valueOf(field) != null)
          field,
    };
    _untouched.addAll(unlocked.where((field) => proxy.valueOf(field) == null));
    _change(_withShown(proxy, shown));
    setState(() {
      _shown = shown;
    });
  }

  Future<void> _validate() async {
    final request = ++_validateRequest;
    String? error;
    try {
      error = await widget.validate(_proxy);
    } catch (_) {
      error = null;
    }
    if (!mounted || request != _validateRequest || error == _coreError) {
      return;
    }
    setState(() {
      _coreError = error;
    });
  }

  void _update(String key, Object? value) {
    if (!_saving) _change(_proxy.withValue(key, value));
  }

  void _updateField(ProxyField field, Object? value) {
    if (!_saving) _change(_proxy.withField(field, value));
  }

  String? _requiredHint(CustomProxy proxy, String key) =>
      proxy.requiredKeys.contains(key)
      ? AppLocalizations.of(context).required
      : null;

  void _updateOption(ProxyField field, Object? value) {
    final proxy = _proxy;
    final next = proxy.withField(field, value);
    final offered = proxy.options;
    _syncShown(
      next,
      unlocked: [
        for (final option in next.options)
          if (!offered.contains(option)) option,
      ],
    );
  }

  Widget _buildTextItem({
    required String title,
    required String key,
    required String? value,
    required int maxLength,
    String? hintText,
    bool digitsOnly = false,
    bool policyName = false,
    bool invalid = false,
    bool obscureText = false,
    Widget? leading,
    Widget? suffix,
    ValueChanged<Object?>? onChanged,
  }) {
    final update = onChanged ?? (Object? value) => _update(key, value);
    final field = FormRowTextField(
      key: ValueKey('$key-$_revision'),
      initialValue: value,
      obscureText: obscureText,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: digitsOnly
          ? TextInputLimits.digitsOnly(maxLength)
          : policyName
          ? TextInputLimits.policyName(maxLength)
          : TextInputLimits.limit(maxLength),
      onChanged: (value) {
        update(digitsOnly ? int.tryParse(value) : value);
      },
      hintText: hintText ?? AppLocalizations.of(context).optional,
    );
    return FormRow(
      title: title,
      invalid: invalid,
      leading: leading,
      trailing: suffix == null
          ? field
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: field),
                suffix,
              ],
            ),
    );
  }

  Widget _buildSecretItem({
    required String title,
    required String key,
    required String? value,
    String? hintText,
    Widget? leading,
    ValueChanged<Object?>? onChanged,
  }) {
    final appLocalizations = AppLocalizations.of(context);
    final revealed = _revealed.contains(key);
    return _buildTextItem(
      title: title,
      key: key,
      value: value,
      maxLength: TextInputLimits.password,
      hintText: hintText,
      obscureText: !revealed,
      leading: leading,
      onChanged: onChanged,
      suffix: CommonMinIconButtonTheme(
        child: IconButton(
          tooltip: revealed
              ? appLocalizations.hidePassword
              : appLocalizations.showPassword,
          onPressed: () {
            setState(() {
              _revealed = {..._revealed}..addOrRemove(key);
            });
          },
          icon: GlyphIcon(revealed ? AppGlyphs.eyeOff : AppGlyphs.eye),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? leading,
  }) {
    return FormRow(
      title: title,
      leading: leading,
      onPressed: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildField(CustomProxy proxy, ProxyField field, {Widget? leading}) {
    final appLocalizations = AppLocalizations.of(context);
    final title = field.label(appLocalizations);
    final key = field.path.join('.');
    final value = proxy.valueOf(field);
    final hintText = _requiredHint(proxy, key);
    void update(Object? value) => _updateField(field, value);
    return switch (field.kind) {
      ProxyFieldKind.text || ProxyFieldKind.number => _buildTextItem(
        title: title,
        key: key,
        value: value?.toString(),
        maxLength: field.maxLength,
        hintText: field.hintText ?? hintText,
        digitsOnly: field.kind == ProxyFieldKind.number,
        leading: leading,
        onChanged: update,
      ),
      ProxyFieldKind.secret => _buildSecretItem(
        title: title,
        key: key,
        value: value?.toString(),
        hintText: hintText,
        leading: leading,
        onChanged: update,
      ),
      ProxyFieldKind.toggle => _buildSwitchItem(
        title: title,
        value: value == true,
        leading: leading,
        onChanged: update,
      ),
      ProxyFieldKind.choice => _buildPickerItem(
        title: title,
        value: value?.toString() ?? hintText ?? appLocalizations.optional,
        leading: leading,
        onPressed: () => _handleSelectChoice(field),
      ),
      ProxyFieldKind.list => _buildListItem(
        proxy,
        title: title,
        key: key,
        itemMaxLength: field.maxLength,
        leading: leading,
      ),
    };
  }

  Future<void> _handleSelectType() async {
    final res = await _selectChoice(
      title: AppLocalizations.of(context).proxyType,
      items: customProxyTypes,
      selectedOf: (state) => state.type,
    );
    if (res == null) {
      return;
    }
    _syncShown(_proxy.withType(res));
  }

  Future<void> _handleSelectChoice(ProxyField field) async {
    final res = await _selectChoice(
      title: field.label(AppLocalizations.of(context)),
      items: _proxy.choicesOf(field),
      selectedOf: (state) => state.valueOf(field)?.toString(),
    );
    if (res == null) {
      return;
    }
    _updateOption(field, res);
  }

  Future<String?> _selectChoice({
    required String title,
    required List<String> items,
    required String? Function(CustomProxy state) selectedOf,
  }) {
    return Navigator.of(context).push(
      PagedSheetRoute(
        builder: (context) => SelectionSheetView<String>(
          title: title,
          sections: [SelectionSection(items: items)],
          labelBuilder: (item) => item,
          selected: selectedOf(_proxy),
          onSelected: (item) => Navigator.of(context).pop(item),
        ),
      ),
    );
  }

  Widget _buildPickerItem({
    required String title,
    required String value,
    required VoidCallback onPressed,
    Widget? leading,
  }) {
    return FormRow(
      title: title,
      leading: leading,
      onPressed: onPressed,
      trailing: Row(
        spacing: 4,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              style: context.listTitleStyle.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const GlyphIcon(AppGlyphs.chevronForward),
        ],
      ),
    );
  }

  Widget _buildTypeItem(String type) {
    return _buildPickerItem(
      title: AppLocalizations.of(context).proxyType,
      value: type,
      onPressed: _handleSelectType,
    );
  }

  Widget _buildListItem(
    CustomProxy proxy, {
    required String title,
    required String key,
    required int itemMaxLength,
    Widget? leading,
  }) {
    final appLocalizations = AppLocalizations.of(context);
    final items = proxy.stringsOf(key);
    return _buildPickerItem(
      title: title,
      value: items.isEmpty
          ? appLocalizations.none
          : appLocalizations.itemsCount(items.length),
      leading: leading,
      onPressed: () => Navigator.of(context).push<void>(
        PagedSheetRoute<void>(
          builder: (_) => _ProxyValuesView(
            title: title,
            itemMaxLength: itemMaxLength,
            read: () => _proxy.stringsOf(key),
            write: (values) => _update(key, values.isEmpty ? null : values),
          ),
        ),
      ),
    );
  }

  void _handleAddOption(List<ProxyField> fields) {
    final appLocalizations = AppLocalizations.of(context);
    final sections = {
      for (final section in ProxyOptionSection.values)
        section: [
          for (final field in fields)
            if (field.section == section) field,
        ],
    };
    Navigator.of(context).push(
      PagedSheetRoute(
        builder: (_) => SelectionSheetView<ProxyField>(
          title: appLocalizations.addSettingEntry,
          sections: [
            for (final MapEntry(:key, :value) in sections.entries)
              if (value.isNotEmpty)
                SelectionSection(
                  label: key.label(appLocalizations),
                  items: value,
                ),
          ],
          labelBuilder: (field) => field.label(appLocalizations),
          selected: null,
          removeOnSelect: true,
          onSelected: _handleAddedOption,
        ),
      ),
    );
  }

  void _handleAddedOption(ProxyField field) {
    if (!mounted) {
      return;
    }
    final proxy = _proxy;
    final initial = switch (field.kind) {
      ProxyFieldKind.toggle => true,
      ProxyFieldKind.choice => proxy.choicesOf(field).firstOrNull,
      _ => null,
    };
    final value = proxy.valueOf(field) ?? initial;
    _shown = {..._shown, field};
    if (value == null) {
      _untouched.add(field);
    }
    _updateOption(field, value);
  }

  void _handleRemoveOption(ProxyField field) {
    _shown = {..._shown}..remove(field);
    _updateOption(field, null);
  }

  Widget _buildOptions(CustomProxy proxy) {
    final appLocalizations = AppLocalizations.of(context);
    final options = proxy.options;
    final remaining = [
      for (final field in options)
        if (!_shown.contains(field)) field,
    ];
    void handleAdd() => _handleAddOption(remaining);
    return generateAnimatedSection(
      title: appLocalizations.options,
      items: [
        for (final field in options)
          if (_shown.contains(field))
            KeyedSubtree(
              key: ValueKey(field),
              child: _buildField(
                proxy,
                field,
                leading: EntryButton.remove(
                  onPressed: () => _handleRemoveOption(field),
                ),
              ),
            ),
        if (remaining.isNotEmpty)
          FormRow(
            key: const ValueKey(#add),
            leading: EntryButton.add(onPressed: handleAdd),
            title: appLocalizations.addSettingEntry,
            titleStyle: TextStyle(color: context.colorScheme.primary),
            onPressed: handleAdd,
          ),
      ],
    );
  }

  Widget _buildEasyTierSection(CustomProxy proxy) {
    final appLocalizations = AppLocalizations.of(context);
    final definition = proxy.definition;
    return generateSection(
      title: appLocalizations.network,
      items: [
        _buildTextItem(
          title: appLocalizations.networkName,
          key: 'network-name',
          value: definition['network-name']?.toString(),
          maxLength: TextInputLimits.name,
          hintText: appLocalizations.networkName,
        ),
        _buildSecretItem(
          title: appLocalizations.networkSecret,
          key: 'network-secret',
          value: definition['network-secret']?.toString(),
        ),
        _buildListItem(
          proxy,
          title: appLocalizations.peers,
          key: 'peers',
          itemMaxLength: TextInputLimits.uri,
        ),
        _buildTextItem(
          title: appLocalizations.virtualIpv4,
          key: 'ipv4',
          value: definition['ipv4']?.toString(),
          maxLength: TextInputLimits.cidr,
          hintText: 'DHCP',
        ),
        _buildTextItem(
          title: appLocalizations.hostname,
          key: 'hostname',
          value: definition['hostname']?.toString(),
          maxLength: TextInputLimits.domain,
        ),
        _buildListItem(
          proxy,
          title: appLocalizations.exitNodes,
          key: 'exit-nodes',
          itemMaxLength: TextInputLimits.cidr,
        ),
      ],
    );
  }

  Future<void> _handleDelete() async {
    if (_saving) return;
    if (await widget.delete?.call() == true && mounted) widget.close();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _change(_withShown(_proxy, _shown));
    setState(() => _saving = true);
    try {
      String? error;
      if (await widget.save((message) => error = message) && mounted) {
        widget.close();
      } else if (mounted) {
        setState(() {
          _submitted = true;
          _coreError = error ?? _coreError;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final proxy = _proxy;
    final nameInvalid = widget.nameInvalid;
    final easyTier = proxy.type == 'easytier';
    final fields = proxy.fields;
    return CommonScaffold(
      iconActions: [
        if (widget.quickEdit != null)
          IconButtonData(
            glyph: AppGlyphs.compose,
            tooltip: appLocalizations.quickEdit,
            onPressed: _saving ? null : _handleQuickEdit,
          ),
      ],
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: appLocalizations.save,
        isLoading: _saving && widget.showSaveProgress,
        onPressed: _saving ? null : _handleSave,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: CustomScrollView(
          slivers: [
            PinnedHeaderSliver(
              child: Builder(
                builder: (context) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    context.contentTopPadding,
                    16,
                    0,
                  ),
                  child: widget.issuesBuilder(context, _coreError, _submitted),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ).copyWith(bottom: 20),
              sliver: SliverList.list(
                children: [
                  generateSection(
                    title: appLocalizations.basicInfo,
                    items: [
                      _buildTextItem(
                        title: appLocalizations.name,
                        key: 'name',
                        value: proxy.name,
                        maxLength: TextInputLimits.proxyName,
                        hintText: appLocalizations.name,
                        policyName: true,
                        invalid: nameInvalid,
                      ),
                      _buildTypeItem(proxy.type),
                      if (!easyTier) ...[
                        _buildTextItem(
                          title: appLocalizations.server,
                          key: 'server',
                          value: proxy.server,
                          maxLength: TextInputLimits.domain,
                          hintText: _requiredHint(proxy, 'server'),
                        ),
                        _buildTextItem(
                          title: appLocalizations.port,
                          key: 'port',
                          value: proxy.port?.toString(),
                          maxLength: TextInputLimits.port,
                          hintText: _requiredHint(proxy, 'port'),
                          digitsOnly: true,
                        ),
                      ],
                      for (final field in fields)
                        if (!field.isCredential) _buildField(proxy, field),
                      _buildSwitchItem(
                        title: 'UDP',
                        value: proxy.definition['udp'] == true,
                        onChanged: (value) => _update('udp', value),
                      ),
                    ],
                  ),
                  if (easyTier) _buildEasyTierSection(proxy),
                  generateSection(
                    title: appLocalizations.authentication,
                    items: [
                      for (final field in fields)
                        if (field.isCredential) _buildField(proxy, field),
                    ],
                  ),
                  _buildOptions(proxy),
                  generateSection(
                    title: appLocalizations.action,
                    items: [
                      if (!_isNew && widget.delete != null)
                        FormRow(
                          title: appLocalizations.delete,
                          titleStyle: TextStyle(
                            color: context.colorScheme.error,
                          ),
                          onPressed: _handleDelete,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      title: _isNew
          ? appLocalizations.addCustomProxy
          : appLocalizations.editProxy,
    );
  }
}

class _ProxyValuesView extends StatefulWidget {
  const _ProxyValuesView({
    required this.title,
    required this.itemMaxLength,
    required this.read,
    required this.write,
  });
  final String title;
  final int itemMaxLength;
  final List<String> Function() read;
  final ValueChanged<List<String>> write;

  @override
  State<_ProxyValuesView> createState() => _ProxyValuesViewState();
}

class _ProxyValuesViewState extends State<_ProxyValuesView> {
  void _write(List<String> values) {
    widget.write(values);
    setState(() {});
  }

  Future<void> _edit([String? value]) async {
    final result = await showListEntryDialog(
      context,
      title: widget.title,
      entries: widget.read(),
      entry: value,
      itemMaxLength: widget.itemMaxLength,
    );
    if (result == null || result.isEmpty || !mounted) return;
    _write(
      value == null
          ? [...widget.read(), ...result]
          : [
              for (final item in widget.read())
                item == value ? result.single : item,
            ],
    );
  }

  @override
  Widget build(BuildContext context) => ListEditorView<String, String>(
    title: widget.title,
    confirmDelete: () => confirmListEditorDelete(context, widget.title),
    items: widget.read(),
    idOf: (item) => item,
    itemBuilder: (context, item, index, editing, selected, toggle) =>
        SelectedDecorationListItem(
          title: Text(item),
          isEditing: editing,
          isSelected: selected,
          onSelected: toggle,
          onPressed: () => _edit(item),
        ),
    onReorder: (oldIndex, newIndex) =>
        _write(widget.read().copyAndReorder(oldIndex, newIndex)),
    onAdd: _edit,
    onDelete: (values) {
      _write([
        for (final item in widget.read())
          if (!values.contains(item)) item,
      ]);
      return true;
    },
    emptyLabel: AppLocalizations.of(context).nullTip(widget.title),
  );
}
