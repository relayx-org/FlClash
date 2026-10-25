import 'package:material_ui/material_ui.dart';
import 'color.dart';
import 'surface.dart';

enum RecordTone { neutral, warning, error }

extension RecordToneExt on RecordTone {
  Color? accentColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      RecordTone.warning => colorScheme.warning,
      RecordTone.error => colorScheme.error,
      RecordTone.neutral => null,
    };
  }

  Color labelColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      RecordTone.neutral => colorScheme.onSurfaceVariant,
      RecordTone.warning => colorScheme.onWarningContainer,
      RecordTone.error => colorScheme.onErrorContainer,
    };
  }

  Color labelContainerColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      RecordTone.neutral => context.raisedSurfaceLevel.colorOf(colorScheme),
      RecordTone.warning => colorScheme.warningContainer,
      RecordTone.error => colorScheme.errorContainer,
    };
  }
}
