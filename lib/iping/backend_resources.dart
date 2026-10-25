import 'dart:async';
import 'dart:convert';

import '../models/filter.dart';
import '../enum/proxy_field.dart';
import '../models/rule.dart';

export '../models/filter.dart';
export '../models/rule.dart';

enum IpingResourceKind {
  proxies,
  ruleProviders,
  filters,
  rules,
  scripts,
  iconSets,
  groupIcons,
}

enum IpingResourceIssue { duplicate, missing, invalid, limit, unavailable }

class IpingResourceException implements Exception {
  const IpingResourceException(this.issue, {this.message});
  final IpingResourceIssue issue;
  final String? message;

  @override
  String toString() => message ?? issue.name;
}

abstract interface class IpingResourceStore<T> {
  int? get itemLimit;
  FutureOr<List<T>> read();
  Future<List<T>> write(List<T> items);
  Future<String?> validate(T item);
}

bool isIpingFilterValid(Filter value) =>
    value.label.trim().isNotEmpty &&
    value.regex.trim().isNotEmpty &&
    utf8.encode(value.label).length <= 256 &&
    utf8.encode(value.regex).length <= 4096 &&
    !RegExp(r'[\x00\r\n]').hasMatch('${value.label}${value.regex}');

void validateIpingFilters(List<Filter> items, {int? limit}) {
  if (limit != null && items.length > limit) {
    throw const IpingResourceException(IpingResourceIssue.limit);
  }
  final names = <String>{};
  for (final item in items) {
    if (!isIpingFilterValid(item)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    if (!names.add(item.label)) {
      throw const IpingResourceException(IpingResourceIssue.duplicate);
    }
  }
}

class IpingCustomProxy {
  IpingCustomProxy({
    required this.id,
    required Map<String, Object?> definition,
    Iterable<String> emptyOptions = const [],
  }) : definition = _freezeObject(definition),
       emptyOptions = Set.unmodifiable(emptyOptions);

  final String id;
  final Map<String, Object?> definition;
  final Set<String> emptyOptions;
  String get name => definition['name'] as String? ?? '';
  String get type => definition['type'] as String? ?? '';

  IpingCustomProxy withDefinition(Map<String, Object?> value) =>
      IpingCustomProxy(id: id, definition: value, emptyOptions: emptyOptions);

  Map<String, Object?> toJson() => {
    'id': id,
    'definition': definition,
    'emptyOptions': emptyOptions.toList(),
  };

  factory IpingCustomProxy.fromJson(Map<String, Object?> json) =>
      IpingCustomProxy(
        id: json['id'] as String,
        definition: Map<String, Object?>.from(json['definition'] as Map),
        emptyOptions: (json['emptyOptions'] as List? ?? const [])
            .cast<String>(),
      );
}

class IpingRuleProvider {
  const IpingRuleProvider({
    required this.id,
    required this.label,
    this.url = '',
    this.behavior = 'classical',
    this.format = 'yaml',
  });

  final String id;
  final String label;
  final String url;
  final String behavior;
  final String format;
  bool get isRemote => url.isNotEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'url': url,
    'behavior': behavior,
    'format': format,
  };

  factory IpingRuleProvider.fromJson(Map<String, Object?> json) =>
      IpingRuleProvider(
        id: json['id'] as String,
        label: json['label'] as String,
        url: json['url'] as String? ?? '',
        behavior: json['behavior'] as String? ?? 'classical',
        format: json['format'] as String? ?? 'yaml',
      );
}

Map<String, Object?> _freezeObject(Map<String, Object?> value) =>
    Map.unmodifiable(value.map((key, value) => MapEntry(key, _freeze(value))));

Object? _freeze(Object? value) => switch (value) {
  final Map value => _freezeObject(Map<String, Object?>.from(value)),
  final List value => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};

bool _resourceText(String value, int limit) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= limit &&
    !RegExp(r'[\x00\r\n]').hasMatch(value);

bool isIpingResourceName(String value) =>
    _resourceText(value, 255) && !value.contains(',');

bool isIpingProviderUrl(String value) {
  final uri = Uri.tryParse(value);
  return _resourceText(value, 2048) &&
      uri != null &&
      const ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.fragment.isEmpty;
}

void validateIpingCustomProxies(List<IpingCustomProxy> items, {int? limit}) {
  _validateResourceEntries(
    items,
    idOf: (item) => item.id,
    nameOf: (item) => item.name,
    limit: limit,
  );
  for (final item in items) {
    if (item.emptyOptions.any(
          (name) => !ProxyField.values.any((field) => field.name == name),
        ) ||
        !_resourceText(item.type, 64) ||
        const {
          'DIRECT',
          'REJECT',
          'REJECT-DROP',
          'PASS',
          'COMPATIBLE',
          'GLOBAL',
        }.contains(item.name) ||
        utf8.encode(jsonEncode(item.definition)).length > 32768) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
  }
}

void validateIpingRuleProviders(
  List<IpingRuleProvider> items, {
  int? limit,
  bool remoteOnly = false,
}) {
  _validateResourceEntries(
    items,
    idOf: (item) => item.id,
    nameOf: (item) => item.label,
    limit: limit,
  );
  for (final item in items) {
    if ((remoteOnly || item.isRemote) && !isIpingProviderUrl(item.url) ||
        !const {'classical', 'domain', 'ipcidr'}.contains(item.behavior) ||
        !const {'yaml', 'text', 'mrs'}.contains(item.format) ||
        item.behavior == 'classical' && item.format == 'mrs') {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
  }
}

void _validateResourceEntries<T>(
  List<T> items, {
  required String Function(T) idOf,
  required String Function(T) nameOf,
  int? limit,
}) {
  if (limit != null && items.length > limit) {
    throw const IpingResourceException(IpingResourceIssue.limit);
  }
  final ids = <String>{};
  final names = <String>{};
  for (final item in items) {
    if (!_resourceText(idOf(item), 128) || !isIpingResourceName(nameOf(item))) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    if (!ids.add(idOf(item)) || !names.add(nameOf(item))) {
      throw const IpingResourceException(IpingResourceIssue.duplicate);
    }
  }
}

class IpingAddedRule {
  const IpingAddedRule({required this.id, required this.rule});
  final String id;
  final Rule rule;
  String get value => rule.rawValue;
  Map<String, Object?> toJson() => {
    'id': id,
    'definition': {...rule.toJson()}
      ..remove('id')
      ..remove('order'),
  };
  factory IpingAddedRule.fromJson(Map<String, Object?> json) => IpingAddedRule(
    id: json['id'] as String,
    rule: Rule.fromJson({
      ...Map<String, Object?>.from(json['definition'] as Map),
      'id': 0,
    }),
  );
}

class IpingScript {
  const IpingScript({
    required this.id,
    required this.label,
    required this.content,
    this.url,
  });
  final String id;
  final String label;
  final String content;
  final String? url;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'content': content,
    if (url != null) 'url': url,
  };
  factory IpingScript.fromJson(Map<String, Object?> json) => IpingScript(
    id: json['id'] as String,
    label: json['label'] as String,
    content: json['content'] as String,
    url: json['url'] as String?,
  );
}

void validateIpingAddedRules(List<IpingAddedRule> items, {int? limit}) {
  if (limit != null && items.length > limit) {
    throw const IpingResourceException(IpingResourceIssue.limit);
  }
  final ids = <String>{};
  for (final item in items) {
    if (!_resourceText(item.id, 128) || !_resourceText(item.value, 2048)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    if (!ids.add(item.id)) {
      throw const IpingResourceException(IpingResourceIssue.duplicate);
    }
    final action = item.value.split(',').first.trim().toUpperCase();
    if (!RuleAction.values.any((value) => value.value == action)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
    final rule = item.rule;
    if (rule.realTarget?.isNotEmpty != true ||
        rule.ruleAction != RuleAction.MATCH &&
            rule.realContent?.isNotEmpty != true ||
        rule.payloadError != null) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
  }
}

void validateIpingScripts(List<IpingScript> items, {int? limit}) {
  _validateResourceEntries(
    items,
    idOf: (item) => item.id,
    nameOf: (item) => item.label,
    limit: limit,
  );
  for (final item in items) {
    if (utf8.encode(item.content).length > 131072 ||
        item.content.contains('\x00') ||
        item.url != null && !isIpingProviderUrl(item.url!)) {
      throw const IpingResourceException(IpingResourceIssue.invalid);
    }
  }
}
