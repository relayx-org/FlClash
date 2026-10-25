import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/config_value.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'filters_page.dart';

class IpingRuleProviderForm extends StatefulWidget {
  const IpingRuleProviderForm({
    super.key,
    required this.provider,
    required this.reservedLabels,
    required this.save,
    required this.errorOf,
    this.editFormat = false,
  });

  final IpingRuleProvider provider;
  final Set<String> reservedLabels;
  final Future<bool> Function(IpingRuleProvider) save;
  final Object? Function() errorOf;
  final bool editFormat;

  @override
  State<IpingRuleProviderForm> createState() => _IpingRuleProviderFormState();
}

class _IpingRuleProviderFormState extends State<IpingRuleProviderForm> {
  late final _label = TextEditingController(text: widget.provider.label);
  late final _url = TextEditingController(text: widget.provider.url);
  late String _behavior = widget.provider.behavior;
  late String _format = widget.provider.format;
  bool _attempted = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  IpingRuleProvider get _value => IpingRuleProvider(
    id: widget.provider.id,
    label: _label.text.trim(),
    url: _url.text.trim(),
    behavior: _behavior,
    format: _format,
  );

  ({bool url, String message})? _issue() {
    final l = AppLocalizations.of(context);
    final value = _value;
    if (value.label.isEmpty) return (url: false, message: l.emptyTip(l.name));
    if (!isIpingResourceName(value.label)) {
      return (url: false, message: l.invalidSettingTip(l.name));
    }
    if (widget.reservedLabels.contains(value.label)) {
      return (url: false, message: l.existsTip(l.name));
    }
    if (widget.editFormat || widget.provider.isRemote) {
      if (!isIpingProviderUrl(value.url)) {
        return (url: true, message: l.providerUrlTip);
      }
    }
    return null;
  }

  void _changed(String _) {
    if (_attempted) setState(() => _error = null);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _attempted = true;
      _error = null;
    });
    if (_issue() != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await widget.save(_value);
      if (mounted && !saved) {
        _error = resourceErrorMessage(
          widget.errorOf(),
          AppLocalizations.of(context),
          label: AppLocalizations.of(context).ruleProviders,
        );
      }
    } catch (error) {
      if (mounted) {
        _error = resourceErrorMessage(
          error,
          AppLocalizations.of(context),
          label: AppLocalizations.of(context).ruleProviders,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final issue = _attempted ? _issue() : null;
    final remote = widget.editFormat || widget.provider.isRemote;
    return FormPage(
      title: l.options,
      onSave: _save,
      saving: _saving,
      error: issue?.message ?? _error,
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: generateSection(
            items: [
              FormRow(
                title: l.name,
                invalid: issue?.url == false,
                trailing: FormRowTextField(
                  controller: _label,
                  hintText: l.required,
                  textInputAction: remote
                      ? TextInputAction.next
                      : TextInputAction.done,
                  inputFormatters: TextInputLimits.policyName(
                    TextInputLimits.name,
                  ),
                  onChanged: _changed,
                  onFieldSubmitted: remote ? null : (_) => _save(),
                ),
              ),
              if (remote)
                FormRow(
                  title: l.url,
                  invalid: issue?.url == true,
                  trailing: FormRowTextField(
                    controller: _url,
                    hintText: l.required,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                    onChanged: _changed,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
              if (widget.editFormat) ...[
                ConfigOptionsValue<String>(
                  title: l.ruleProviderBehavior,
                  value: _behavior,
                  options: const ['classical', 'domain', 'ipcidr'],
                  textBuilder: (value) => value,
                  onChanged: (value) => setState(() {
                    _behavior = value;
                    if (value == 'classical' && _format == 'mrs') {
                      _format = 'yaml';
                    }
                  }),
                ),
                ConfigOptionsValue<String>(
                  title: l.ruleProviderFormat,
                  value: _format,
                  options: [
                    'yaml',
                    'text',
                    if (_behavior != 'classical') 'mrs',
                  ],
                  textBuilder: (value) => value,
                  onChanged: (value) => setState(() => _format = value),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
