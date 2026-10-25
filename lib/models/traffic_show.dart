import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/traffic_show.freezed.dart';

@freezed
abstract class TrafficShow with _$TrafficShow {
  const factory TrafficShow({required String value, required String unit}) =
      _TrafficShow;
}

extension TrafficShowExt on TrafficShow {
  String get show => '$value$unit';
}
