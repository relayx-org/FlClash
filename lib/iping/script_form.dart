import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'filters_page.dart';

class IpingScriptForm extends StatefulWidget {
  const IpingScriptForm({
    super.key,
    required this.script,
    required this.reservedLabels,
    required this.save,
    required this.errorOf,
  });
  final IpingScript script;
  final Set<String> reservedLabels;
  final Future<bool> Function(IpingScript) save;
  final Object? Function() errorOf;
  @override
  State<IpingScriptForm> createState() => _IpingScriptFormState();
}

class _IpingScriptFormState extends State<IpingScriptForm> {
  late final _label = TextEditingController(text: widget.script.label);
  late final _content = TextEditingController(text: widget.script.content);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _label.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    if (_label.text.trim().isEmpty) {
      setState(() => _error = l.emptyTip(l.name));
      return;
    }
    if (widget.reservedLabels.contains(_label.text.trim())) {
      setState(() => _error = l.existsTip(l.name));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.save(
        IpingScript(
          id: widget.script.id,
          label: _label.text.trim(),
          content: _content.text,
          url: widget.script.url,
        ),
      );
      if (mounted && !saved) {
        _error = resourceErrorMessage(widget.errorOf(), l, label: l.script);
      }
    } catch (error) {
      if (mounted) _error = resourceErrorMessage(error, l, label: l.script);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmPop(BuildContext context) async {
    if (_saving) return false;
    final l = AppLocalizations.of(context);
    final choice = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: l.tip,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.save),
          ),
        ],
        child: Text(l.saveChanges),
      ),
    );
    if (choice == null || !mounted) return false;
    if (!choice) return true;
    await _save();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_label, _content]),
      builder: (context, _) => CommonPopScope(
        onPop:
            _saving ||
                _label.text != widget.script.label ||
                _content.text != widget.script.content
            ? _confirmPop
            : null,
        child: FormPage(
          title: l.script,
          onSave: _save,
          saving: _saving,
          error: _error,
          children: [
            AbsorbPointer(
              absorbing: _saving,
              child: generateSection(
                items: [
                  FormRow(
                    title: l.name,
                    trailing: FormRowTextField(
                      controller: _label,
                      hintText: l.required,
                      inputFormatters: TextInputLimits.limit(
                        TextInputLimits.name,
                      ),
                    ),
                  ),
                  DecorationListItem(
                    title: TextField(
                      controller: _content,
                      maxLines: null,
                      autocorrect: false,
                      inputFormatters: TextInputLimits.limit(131072),
                      style: AppTextStyle.subheadline
                          .of(context)
                          .toJetBrainsMono,
                      decoration: const InputDecoration(
                        hintText: 'function main(config) { return config; }',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
