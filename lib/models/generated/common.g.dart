// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../common.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Package _$PackageFromJson(Map<String, dynamic> json) => _Package(
  packageName: json['packageName'] as String,
  label: json['label'] as String,
  system: json['system'] as bool,
  internet: json['internet'] as bool,
  lastUpdateTime: (json['lastUpdateTime'] as num).toInt(),
);

Map<String, dynamic> _$PackageToJson(_Package instance) => <String, dynamic>{
  'packageName': instance.packageName,
  'label': instance.label,
  'system': instance.system,
  'internet': instance.internet,
  'lastUpdateTime': instance.lastUpdateTime,
};

_DnsQuery _$DnsQueryFromJson(Map<String, dynamic> json) => _DnsQuery(
  domain: json['domain'] as String,
  type: json['type'] as String,
  initiator: $enumDecodeNullable(
    _$DnsQueryInitiatorEnumMap,
    json['initiator'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  upstream: json['upstream'] as String? ?? '',
  cached: json['cached'] as bool? ?? false,
  answers:
      (json['answers'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  rcode: json['rcode'] as String? ?? '',
  error: json['error'] as String? ?? '',
  delay: (json['delay'] as num?)?.toInt() ?? 0,
  time: DateTime.parse(json['time'] as String),
);

Map<String, dynamic> _$DnsQueryToJson(_DnsQuery instance) => <String, dynamic>{
  'domain': instance.domain,
  'type': instance.type,
  'initiator': _$DnsQueryInitiatorEnumMap[instance.initiator],
  'upstream': instance.upstream,
  'cached': instance.cached,
  'answers': instance.answers,
  'rcode': instance.rcode,
  'error': instance.error,
  'delay': instance.delay,
  'time': instance.time.toIso8601String(),
};

const _$DnsQueryInitiatorEnumMap = {
  DnsQueryInitiator.app: 'app',
  DnsQueryInitiator.rule: 'rule',
  DnsQueryInitiator.direct: 'direct',
  DnsQueryInitiator.proxy: 'proxy',
  DnsQueryInitiator.other: 'other',
};

_DAVProps _$DAVPropsFromJson(Map<String, dynamic> json) => _DAVProps(
  uri: json['uri'] as String,
  user: json['user'] as String,
  password: json['password'] == null
      ? ''
      : _decodeDavPassword(json['password'] as String?),
  fileName: json['fileName'] as String? ?? defaultDavFileName,
);

Map<String, dynamic> _$DAVPropsToJson(_DAVProps instance) => <String, dynamic>{
  'uri': instance.uri,
  'user': instance.user,
  'password': _encodeDavPassword(instance.password),
  'fileName': instance.fileName,
};

_Group _$GroupFromJson(Map<String, dynamic> json) => _Group(
  type: GroupType.parse(json['type'] as String),
  all:
      (json['all'] as List<dynamic>?)
          ?.map((e) => Proxy.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  now: json['now'] as String?,
  hidden: json['hidden'] as bool?,
  testUrl: json['testUrl'] as String?,
  icon: json['icon'] as String? ?? '',
  name: json['name'] as String,
);

Map<String, dynamic> _$GroupToJson(_Group instance) => <String, dynamic>{
  'type': _$GroupTypeEnumMap[instance.type]!,
  'all': instance.all,
  'now': instance.now,
  'hidden': instance.hidden,
  'testUrl': instance.testUrl,
  'icon': instance.icon,
  'name': instance.name,
};

const _$GroupTypeEnumMap = {
  GroupType.Selector: 'select',
  GroupType.URLTest: 'url-test',
  GroupType.Fallback: 'fallback',
  GroupType.LoadBalance: 'load-balance',
  GroupType.Relay: 'relay',
};

_HotKeyAction _$HotKeyActionFromJson(Map<String, dynamic> json) =>
    _HotKeyAction(
      action: $enumDecode(_$HotActionEnumMap, json['action']),
      key: (json['key'] as num?)?.toInt(),
      modifiers:
          (json['modifiers'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$KeyboardModifierEnumMap, e))
              .toSet() ??
          const {},
    );

Map<String, dynamic> _$HotKeyActionToJson(_HotKeyAction instance) =>
    <String, dynamic>{
      'action': _$HotActionEnumMap[instance.action]!,
      'key': instance.key,
      'modifiers': instance.modifiers
          .map((e) => _$KeyboardModifierEnumMap[e]!)
          .toList(),
    };

const _$HotActionEnumMap = {
  HotAction.start: 'start',
  HotAction.view: 'view',
  HotAction.mode: 'mode',
  HotAction.proxy: 'proxy',
  HotAction.tun: 'tun',
  HotAction.ruleMode: 'ruleMode',
  HotAction.globalMode: 'globalMode',
  HotAction.directMode: 'directMode',
  HotAction.delayTest: 'delayTest',
  HotAction.updateProfiles: 'updateProfiles',
  HotAction.copyEnv: 'copyEnv',
  HotAction.exit: 'exit',
};

const _$KeyboardModifierEnumMap = {
  KeyboardModifier.alt: 'alt',
  KeyboardModifier.capsLock: 'capsLock',
  KeyboardModifier.control: 'control',
  KeyboardModifier.fn: 'fn',
  KeyboardModifier.meta: 'meta',
  KeyboardModifier.shift: 'shift',
};

_Script _$ScriptFromJson(Map<String, dynamic> json) => _Script(
  id: (json['id'] as num).toInt(),
  label: json['label'] as String,
  lastUpdateTime: DateTime.parse(json['lastUpdateTime'] as String),
  url: json['url'] as String?,
  order: (json['order'] as num?)?.toInt(),
);

Map<String, dynamic> _$ScriptToJson(_Script instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'lastUpdateTime': instance.lastUpdateTime.toIso8601String(),
  'url': instance.url,
  'order': instance.order,
};

_IconSetIcon _$IconSetIconFromJson(Map<String, dynamic> json) =>
    _IconSetIcon(name: json['name'] as String, url: json['url'] as String);

Map<String, dynamic> _$IconSetIconToJson(_IconSetIcon instance) =>
    <String, dynamic>{'name': instance.name, 'url': instance.url};
