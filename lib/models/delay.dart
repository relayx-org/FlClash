import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/delay.freezed.dart';
part 'generated/delay.g.dart';

@freezed
abstract class Delay with _$Delay {
  const factory Delay({required String name, required String url, int? value}) =
      _Delay;

  factory Delay.fromJson(Map<String, Object?> json) => _$DelayFromJson(json);
}
