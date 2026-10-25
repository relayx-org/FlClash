import 'dart:async';
import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/iping/backend_settings.dart';
import 'package:fl_clash/iping/settings_error.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/confirmation.dart';
import 'package:material_ui/material_ui.dart';

typedef PortValues = ({int mixed, int http, int socks, int redir, int tproxy});
const defaultPortValues = (mixed: 7890, http: 0, socks: 0, redir: 0, tproxy: 0);

class _PortField {
  final TextEditingController controller;
  final String Function(AppLocalizations appLocalizations) label;
  final bool allowDisabled;

  const _PortField({
    required this.controller,
    required this.label,
    this.allowDisabled = true,
  });
}

class PortSettingsForm extends StatefulWidget {
  const PortSettingsForm({
    super.key,
    required this.value,
    required this.onSave,
    this.defaults = defaultPortValues,
  });
  final PortValues value;
  final PortValues defaults;
  final FutureOr<void> Function(PortValues) onSave;

  @override
  State<PortSettingsForm> createState() => _PortFormState();
}

class _PortFormState extends State<PortSettingsForm> {
  bool _saving = false;
  String? _error;
  late final TextEditingController _mixedPortController;
  late final TextEditingController _portController;
  late final TextEditingController _socksPortController;
  late final TextEditingController _redirPortController;
  late final TextEditingController _tProxyPortController;
  late final List<_PortField> _fields;

  @override
  void initState() {
    super.initState();
    final ports = widget.value;
    _mixedPortController = TextEditingController(text: ports.mixed.toString());
    _portController = TextEditingController(text: ports.http.toString());
    _socksPortController = TextEditingController(text: ports.socks.toString());
    _redirPortController = TextEditingController(text: ports.redir.toString());
    _tProxyPortController = TextEditingController(
      text: ports.tproxy.toString(),
    );
    _fields = [
      _PortField(
        controller: _mixedPortController,
        label: (appLocalizations) => appLocalizations.mixedPort,
        allowDisabled: false,
      ),
      _PortField(
        controller: _portController,
        label: (appLocalizations) => appLocalizations.port,
      ),
      _PortField(
        controller: _socksPortController,
        label: (appLocalizations) => appLocalizations.socksPort,
      ),
      _PortField(
        controller: _redirPortController,
        label: (appLocalizations) => appLocalizations.redirPort,
      ),
      _PortField(
        controller: _tProxyPortController,
        label: (appLocalizations) => appLocalizations.tproxyPort,
      ),
    ];
  }

  Future<void> _handleReset() async {
    final l = AppLocalizations.of(context);
    final res = await confirmChange(
      context,
      message: l.resetTip,
      confirmText: l.reset,
    );
    if (res == true && mounted) await _save(widget.defaults);
  }

  Future<void> _save(PortValues values) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(values);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              ipingSettingsErrorMessage(error, AppLocalizations.of(context)) ??
              error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<_PortField, String> _issues(AppLocalizations appLocalizations) {
    return {
      for (final field in _fields)
        field: ?validatePort(field, field.controller.text, appLocalizations),
    };
  }

  void _handleUpdate() {
    if (_issues(AppLocalizations.of(context)).isNotEmpty) {
      return;
    }
    unawaited(
      _save((
        mixed: int.parse(_mixedPortController.text),
        http: int.parse(_portController.text),
        socks: int.parse(_socksPortController.text),
        redir: int.parse(_redirPortController.text),
        tproxy: int.parse(_tProxyPortController.text),
      )),
    );
  }

  @visibleForTesting
  String? validatePort(
    _PortField field,
    String? value,
    AppLocalizations appLocalizations,
  ) {
    final label = field.label(appLocalizations);
    if (value == null || value.isEmpty) {
      return appLocalizations.emptyTip(label);
    }
    final port = int.tryParse(value);
    if (port == null) {
      return appLocalizations.numberTip(label);
    }
    if (!isIpingPortValid(port, allowDisabled: field.allowDisabled)) {
      return appLocalizations.portTip(label);
    }
    final others = _fields
        .where((item) => item != field)
        .map((item) => int.tryParse(item.controller.text.trim()));
    if (hasIpingPortConflict(port, others)) {
      return appLocalizations.portConflictTip;
    }
    return null;
  }

  @override
  void dispose() {
    _mixedPortController.dispose();
    _portController.dispose();
    _socksPortController.dispose();
    _redirPortController.dispose();
    _tProxyPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final issues = _issues(appLocalizations);
    return FormPage(
      title: appLocalizations.port,
      onSave: _handleUpdate,
      error: _error ?? issues.values.firstOrNull,
      saving: _saving,
      children: [
        generateSection(
          items: [
            for (final field in _fields)
              FormRow(
                title: field.label(appLocalizations),
                invalid: issues.containsKey(field),
                trailing: FormRowTextField(
                  controller: field.controller,
                  hintText: appLocalizations.required,
                  keyboardType: TextInputType.number,
                  textInputAction: field == _fields.last
                      ? TextInputAction.done
                      : TextInputAction.next,
                  inputFormatters: TextInputLimits.digitsOnly(
                    TextInputLimits.port,
                  ),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _handleUpdate(),
                ),
              ),
          ],
        ),
        generateSection(
          items: [
            FormRow(title: appLocalizations.reset, onPressed: _handleReset),
          ],
        ),
      ],
    );
  }
}
