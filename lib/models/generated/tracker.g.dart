// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tracker.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Metadata _$MetadataFromJson(Map<String, dynamic> json) => _Metadata(
  uid: (json['uid'] as num?)?.toInt() ?? 0,
  network: json['network'] as String? ?? '',
  sourceIP: json['sourceIP'] as String? ?? '',
  sourcePort: json['sourcePort'] as String? ?? '',
  destinationIP: json['destinationIP'] as String? ?? '',
  destinationPort: json['destinationPort'] as String? ?? '',
  host: json['host'] as String? ?? '',
  dnsMode: $enumDecodeNullable(_$DnsModeEnumMap, json['dnsMode']),
  process: json['process'] as String? ?? '',
  processPath: json['processPath'] as String? ?? '',
  remoteDestination: json['remoteDestination'] as String? ?? '',
  sourceGeoIP:
      (json['sourceGeoIP'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  destinationGeoIP:
      (json['destinationGeoIP'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  destinationIPASN: json['destinationIPASN'] as String? ?? '',
  sourceIPASN: json['sourceIPASN'] as String? ?? '',
  specialRules: json['specialRules'] as String? ?? '',
  specialProxy: json['specialProxy'] as String? ?? '',
);

Map<String, dynamic> _$MetadataToJson(_Metadata instance) => <String, dynamic>{
  'uid': instance.uid,
  'network': instance.network,
  'sourceIP': instance.sourceIP,
  'sourcePort': instance.sourcePort,
  'destinationIP': instance.destinationIP,
  'destinationPort': instance.destinationPort,
  'host': instance.host,
  'dnsMode': _$DnsModeEnumMap[instance.dnsMode],
  'process': instance.process,
  'processPath': instance.processPath,
  'remoteDestination': instance.remoteDestination,
  'sourceGeoIP': instance.sourceGeoIP,
  'destinationGeoIP': instance.destinationGeoIP,
  'destinationIPASN': instance.destinationIPASN,
  'sourceIPASN': instance.sourceIPASN,
  'specialRules': instance.specialRules,
  'specialProxy': instance.specialProxy,
};

const _$DnsModeEnumMap = {
  DnsMode.normal: 'normal',
  DnsMode.fakeIp: 'fake-ip',
  DnsMode.redirHost: 'redir-host',
  DnsMode.hosts: 'hosts',
};

_TrackerInfo _$TrackerInfoFromJson(Map<String, dynamic> json) => _TrackerInfo(
  id: json['id'] as String,
  upload: (json['upload'] as num?)?.toInt() ?? 0,
  download: (json['download'] as num?)?.toInt() ?? 0,
  start: DateTime.parse(json['start'] as String),
  metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>),
  chains: (json['chains'] as List<dynamic>).map((e) => e as String).toList(),
  rule: json['rule'] as String,
  rulePayload: json['rulePayload'] as String,
  downloadSpeed: (json['downloadSpeed'] as num?)?.toInt(),
  uploadSpeed: (json['uploadSpeed'] as num?)?.toInt(),
);

Map<String, dynamic> _$TrackerInfoToJson(_TrackerInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'upload': instance.upload,
      'download': instance.download,
      'start': instance.start.toIso8601String(),
      'metadata': instance.metadata,
      'chains': instance.chains,
      'rule': instance.rule,
      'rulePayload': instance.rulePayload,
      'downloadSpeed': instance.downloadSpeed,
      'uploadSpeed': instance.uploadSpeed,
    };
