import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/traffic.freezed.dart';
part 'generated/traffic.g.dart';

@freezed
abstract class Traffic with _$Traffic {
  const factory Traffic({@Default(0) num up, @Default(0) num down}) = _Traffic;

  factory Traffic.fromJson(Map<String, Object?> json) =>
      _$TrafficFromJson(json);
}
