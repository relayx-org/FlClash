import 'package:material_ui/material_ui.dart';
import 'ui.dart';

class ConfigToggleValue extends StatelessWidget {
  const ConfigToggleValue({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
  });
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => ListItem.toggle(
    leading: leading,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

class ConfigOptionsValue<T> extends StatelessWidget {
  const ConfigOptionsValue({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.textBuilder,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) textBuilder;
  final ValueChanged<T> onChanged;
  final Widget? subtitle;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => ListItem<T>.options(
    leading: leading,
    title: Text(title),
    subtitle: subtitle,
    options: options,
    value: value,
    textBuilder: textBuilder,
    onChanged: onChanged,
  );
}

class ConfigTextValue extends StatelessWidget {
  const ConfigTextValue({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.leading,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.resetValue,
  });
  final String title;
  final String value;
  final ValueChanged<String?> onChanged;
  final Widget? leading;
  final int? maxLength;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final String? resetValue;
  @override
  Widget build(BuildContext context) => ListItem.input(
    leading: leading,
    title: Text(title),
    subtitle: value.isEmpty ? null : Text(value),
    dialogTitle: title,
    value: value,
    maxLength: maxLength,
    keyboardType: keyboardType,
    validator: validator,
    resetValue: resetValue,
    onChanged: onChanged,
  );
}
