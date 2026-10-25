// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Log _$LogFromJson(Map<String, dynamic> json) => _Log(
  logLevel:
      $enumDecodeNullable(_$LogLevelEnumMap, json['LogLevel']) ?? LogLevel.info,
  payload: json['Payload'] as String? ?? '',
  dateTime: _logDateTime(json['dateTime']),
);

Map<String, dynamic> _$LogToJson(_Log instance) => <String, dynamic>{
  'LogLevel': _$LogLevelEnumMap[instance.logLevel]!,
  'Payload': instance.payload,
  'dateTime': instance.dateTime,
};

const _$LogLevelEnumMap = {
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warning: 'warning',
  LogLevel.error: 'error',
  LogLevel.silent: 'silent',
};
