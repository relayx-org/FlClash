// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../delay.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Delay _$DelayFromJson(Map<String, dynamic> json) => _Delay(
  name: json['name'] as String,
  url: json['url'] as String,
  value: (json['value'] as num?)?.toInt(),
);

Map<String, dynamic> _$DelayToJson(_Delay instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url,
  'value': instance.value,
};
