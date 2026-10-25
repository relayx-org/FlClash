// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../resource_bindings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IpingResourceBindings _$IpingResourceBindingsFromJson(
  Map<String, dynamic> json,
) => _IpingResourceBindings(
  proxies:
      (json['proxies'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
      const {},
  providers:
      (json['providers'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
      const {},
  filters:
      (json['filters'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
      const {},
  rules:
      (json['rules'] as List<dynamic>?)?.map((e) => e as String).toSet() ??
      const {},
  script: json['script'] as String?,
);

Map<String, dynamic> _$IpingResourceBindingsToJson(
  _IpingResourceBindings instance,
) => <String, dynamic>{
  'proxies': instance.proxies.toList(),
  'providers': instance.providers.toList(),
  'filters': instance.filters.toList(),
  'rules': instance.rules.toList(),
  'script': instance.script,
};
