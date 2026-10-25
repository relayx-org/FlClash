import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/filter.freezed.dart';
part 'generated/filter.g.dart';

@freezed
abstract class Filter with _$Filter {
  const factory Filter({required String label, required String regex}) =
      _Filter;

  factory Filter.fromJson(Map<String, Object?> json) => _$FilterFromJson(json);
}
