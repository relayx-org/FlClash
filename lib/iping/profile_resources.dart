import 'dart:convert';

import 'package:collection/collection.dart';

import '../models/resource_bindings.dart';
import 'backend_resources.dart';

export '../models/resource_bindings.dart';

class IpingProfileResources {
  const IpingProfileResources({
    required this.profileId,
    required this.label,
    this.bindings = const IpingResourceBindings(),
  });

  final String profileId;
  final String label;
  final IpingResourceBindings bindings;
}

Map<String, dynamic> applyIpingProfileResources(
  Map<String, dynamic> source, {
  required List<Map<String, dynamic>> proxies,
  required List<Filter> filters,
}) {
  if (proxies.isEmpty && filters.isEmpty) return source;
  final config = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  final current = (config['proxies'] as List? ?? const []).toList();
  final groups = (config['proxy-groups'] as List? ?? const []).toList();
  final byName = <String, Map>{
    for (final value in [...current, ...groups])
      if (value is Map && value['name'] is String)
        value['name'] as String: value,
  };
  final names = <String>[];
  for (final proxy in proxies) {
    final name = proxy['name'] as String;
    if (byName[name] case final existing?) {
      if (!const DeepCollectionEquality().equals(existing, proxy)) {
        throw const IpingResourceException(IpingResourceIssue.duplicate);
      }
    } else {
      byName[name] = proxy;
      current.add(proxy);
    }
    names.add(name);
  }
  for (final filter in filters) {
    if (byName.containsKey(filter.label)) {
      throw const IpingResourceException(IpingResourceIssue.duplicate);
    }
    final group = <String, dynamic>{
      'name': filter.label,
      'type': 'select',
      'include-all-proxies': true,
      'include-all-providers': true,
      'filter': filter.regex,
    };
    byName[filter.label] = group;
    groups.add(group);
    names.add(filter.label);
  }
  final filterNames = filters.map((item) => item.label).toSet();
  for (final group in groups.whereType<Map>()) {
    if (group['type'] != 'select' || filterNames.contains(group['name'])) {
      continue;
    }
    final members = (group['proxies'] as List? ?? const []).toList();
    for (final name in names) {
      if (group['name'] != name && !members.contains(name)) members.add(name);
    }
    group['proxies'] = members;
  }
  config['proxies'] = current;
  config['proxy-groups'] = groups;
  return config;
}

void validateIpingResourceBindings(
  IpingResourceBindings value, {
  required Set<String> proxies,
  required Set<String> providers,
  required Set<String> filters,
  Set<String> rules = const {},
  Set<String> scripts = const {},
}) {
  if (!proxies.containsAll(value.proxies) ||
      !providers.containsAll(value.providers) ||
      !filters.containsAll(value.filters) ||
      !rules.containsAll(value.rules) ||
      value.script != null && !scripts.contains(value.script)) {
    throw const IpingResourceException(IpingResourceIssue.missing);
  }
}
