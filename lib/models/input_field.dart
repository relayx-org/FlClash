import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/input_field.freezed.dart';

typedef Validator = String? Function(String? value);

@freezed
abstract class Field with _$Field {
  const factory Field({
    required String label,
    required String value,
    Validator? validator,
  }) = _Field;
}
