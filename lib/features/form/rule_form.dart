import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/models/rule.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'form_page.dart';
import 'form_row.dart';

enum _RuleField { content, target }

class RuleForm extends StatefulWidget {
  final Rule? rule;
  final bool? isNew;
  final Future<bool> Function(Rule)? onSave;
  final String? Function()? errorMessage;

  const RuleForm({
    super.key,
    this.rule,
    this.isNew,
    this.onSave,
    this.errorMessage,
  });

  @override
  State<RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<RuleForm> {
  late RuleAction _ruleAction;
  late String _ruleTarget;
  late final TextEditingController _contentController;
  late bool _noResolve;
  late bool _src;
  bool _attempted = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _ruleAction = rule?.ruleAction ?? RuleAction.addedRuleActions.first;
    _ruleTarget = rule?.ruleTarget ?? RuleTarget.ruleTargetNames.first;
    _contentController = TextEditingController(text: rule?.realContent);
    _noResolve = rule?.noResolve ?? false;
    _src = rule?.src ?? false;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  ({_RuleField field, String message})? _issue() {
    final appLocalizations = AppLocalizations.of(context);
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      return (
        field: _RuleField.content,
        message: appLocalizations.emptyTip(appLocalizations.content),
      );
    }
    final payloadError = Rule(
      ruleAction: _ruleAction,
      content: content,
    ).payloadError;
    if (payloadError != null) {
      return (
        field: _RuleField.content,
        message: switch (payloadError) {
          RulePayloadError.network => appLocalizations.invalidNetworkContent,
          RulePayloadError.numberRange => appLocalizations.invalidRangeContent,
          RulePayloadError.dscpRange => appLocalizations.invalidDscpContent,
        },
      );
    }
    if (_ruleTarget.isEmpty) {
      return (
        field: _RuleField.target,
        message: appLocalizations.splitStrategyNotEmpty,
      );
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_saving) return;
    if (_issue() != null) {
      setState(() => _attempted = true);
      return;
    }
    final value = (widget.rule ?? Rule(id: snowflake.id)).copyWith(
      ruleAction: _ruleAction,
      content: _ruleAction == RuleAction.RULE_SET
          ? null
          : _contentController.text,
      ruleProvider: _ruleAction == RuleAction.RULE_SET
          ? _contentController.text
          : null,
      ruleTarget: _ruleTarget,
      noResolve: _noResolve,
      src: _src,
    );
    if (widget.onSave == null) {
      Navigator.of(context).pop(value);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave!(value);
      if (mounted && !saved) _error = widget.errorMessage?.call();
    } catch (error) {
      if (mounted) _error = error.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (saved && mounted) Navigator.of(context).pop();
  }

  String _targetLabel(String target) => target == RuleAction.MATCH.value
      ? AppLocalizations.of(context).matchTarget
      : target;

  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FormRow(
      title: title,
      onPressed: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final issue = _attempted ? _issue() : null;
    final targets = [...RuleTarget.ruleTargetNames, RuleAction.MATCH.value];
    return FormPage(
      title: !(widget.isNew ?? widget.rule == null)
          ? appLocalizations.editRule
          : appLocalizations.addRule,
      onSave: _handleSubmit,
      saving: _saving,
      error: issue?.message ?? _error,
      children: [
        generateSection(
          title: appLocalizations.basicInfo,
          items: [
            ListItem<RuleAction>.options(
              title: Text(appLocalizations.proxyType),
              options: [...RuleAction.addedRuleActions, RuleAction.RULE_SET],
              value: _ruleAction,
              textBuilder: (action) => action.value,
              onChanged: (action) {
                setState(() {
                  _ruleAction = action;
                });
              },
            ),
            FormRow(
              title: appLocalizations.content,
              invalid: issue?.field == _RuleField.content,
              trailing: FormRowTextField(
                controller: _contentController,
                hintText: appLocalizations.inputRuleContent,
                autocorrect: false,
                inputFormatters: TextInputLimits.limit(TextInputLimits.rule),
                onChanged: (_) {
                  if (_attempted) {
                    setState(() {});
                  }
                },
                onFieldSubmitted: (_) => _handleSubmit(),
              ),
            ),
            ListItem<String>.options(
              title: Text(appLocalizations.splitStrategy),
              options: [
                if (!targets.contains(_ruleTarget)) _ruleTarget,
                ...targets,
              ],
              value: _ruleTarget,
              textBuilder: _targetLabel,
              onChanged: (target) {
                setState(() {
                  _ruleTarget = target;
                });
              },
            ),
          ],
        ),
        if (_ruleAction.hasParams)
          generateSection(
            title: appLocalizations.additionalParameters,
            items: [
              _buildSwitchRow(
                title: appLocalizations.noResolveHostname,
                value: _noResolve,
                onChanged: (value) {
                  setState(() {
                    _noResolve = value;
                  });
                },
              ),
              _buildSwitchRow(
                title: appLocalizations.matchSourceIp,
                value: _src,
                onChanged: (value) {
                  setState(() {
                    _src = value;
                  });
                },
              ),
            ],
          ),
      ],
    );
  }
}
