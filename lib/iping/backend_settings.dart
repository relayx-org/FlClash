import 'dart:convert';

import 'settings_validation.dart';
import 'backend_resources.dart';
import 'profile_resources.dart';

enum IpingSettingsIssue { unsupported, invalid, portRange, portConflict }

class IpingSettingsException implements Exception {
  const IpingSettingsException(this.key, this.issue);

  final String key;
  final IpingSettingsIssue issue;

  @override
  String toString() => 'invalid_setting: $key (${issue.name})';
}

const ipingPortKeys = {
  'mixed-port',
  'port',
  'socks-port',
  'redir-port',
  'tproxy-port',
};

bool isIpingPortValid(int port, {bool allowDisabled = true}) =>
    allowDisabled && port == 0 || port >= 1024 && port <= 49151;

bool hasIpingPortConflict(int port, Iterable<int?> others) =>
    port != 0 && others.contains(port);

const _booleanKeys = {'allow-lan', 'ipv6', 'unified-delay', 'tcp-concurrent'};

const _choices = {
  'log-level': ['silent', 'error', 'warning', 'info', 'debug'],
  'find-process-mode': ['off', 'strict', 'always'],
  'geodata-loader': ['standard', 'memconservative'],
};

class IpingSettings {
  IpingSettings(
    Map<String, Object?> values, {
    Map<String, List<String>> choices = const {},
    Map<String, bool> overrides = const {},
    int? collectionLimit = 128,
  }) : values = Map.unmodifiable(
         values.map((key, value) => MapEntry(key, _freeze(value))),
       ),
       _supportedChoices = Map.unmodifiable({
         ..._choices,
         ...ipingNetworkOptions,
         for (final entry in choices.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       overrides = Map.unmodifiable(overrides),
       _collectionLimit = collectionLimit;

  static const generalKeys = {
    ...ipingPortKeys,
    ..._booleanKeys,
    'log-level',
    'find-process-mode',
    'geodata-loader',
    'global-ua',
    'disable-keep-alive',
    'keep-alive-idle',
    'keep-alive-interval',
    'routing-mark',
    'hosts',
  };

  final Map<String, Object?> values;

  /// Entries identify overridable keys; false follows the profile.
  final Map<String, bool> overrides;
  final int? _collectionLimit;
  final Map<String, List<String>> _supportedChoices;

  Object? operator [](String key) => values[key];

  bool flag(String key) => values[key] == true;
  String text(String key) => values[key]?.toString() ?? '';
  int port(String key) => (values[key] as num?)?.toInt() ?? 0;

  Map<String, String> stringMap(String key) => {
    for (final entry in (values[key] as Map? ?? const {}).entries)
      entry.key as String: switch (entry.value) {
        final List items => items.join(','),
        final value => value.toString(),
      },
  };

  List<String> options(String key) => _supportedChoices[key] ?? const [];

  void validate(Map<String, Object?> changes) {
    for (final entry in changes.entries) {
      final key = entry.key;
      final value = entry.value;
      if (!values.containsKey(key)) {
        throw IpingSettingsException(key, IpingSettingsIssue.unsupported);
      }
      if (value == null && overrides.containsKey(key)) continue;
      if (key == 'custom.rules' || key == 'custom.scripts') {
        if (value is! List) _invalid(key);
        try {
          if (key == 'custom.rules') {
            validateIpingAddedRules([
              for (final item in value)
                IpingAddedRule.fromJson(Map<String, Object?>.from(item as Map)),
            ], limit: _collectionLimit);
          } else {
            validateIpingScripts([
              for (final item in value)
                IpingScript.fromJson(Map<String, Object?>.from(item as Map)),
            ], limit: _collectionLimit);
          }
        } catch (_) {
          _invalid(key);
        }
        continue;
      }
      if (key == 'custom.bindings') {
        if (value is! Map) _invalid(key);
        try {
          IpingResourceBindings.fromJson(Map<String, Object?>.from(value));
        } catch (_) {
          _invalid(key);
        }
        continue;
      }
      if (key == 'custom.filters') {
        if (value is! List) _invalid(key);
        try {
          validateIpingFilters([
            for (final item in value)
              Filter.fromJson(Map<String, Object?>.from(item as Map)),
          ], limit: _collectionLimit);
        } catch (_) {
          _invalid(key);
        }
      }
      if (isIpingNetworkValueValid(
            key,
            value,
            collectionLimit: _collectionLimit,
          ) ==
          false) {
        _invalid(key);
      }
      if (ipingPortKeys.contains(key)) {
        if (value is! int ||
            !isIpingPortValid(value, allowDisabled: key != 'mixed-port')) {
          throw IpingSettingsException(key, IpingSettingsIssue.portRange);
        }
      } else if (_booleanKeys.contains(key)) {
        if (value is! bool) _invalid(key);
      } else if (_supportedChoices[key] case final choices?) {
        if (!choices.contains(value)) _invalid(key);
      } else if (key == 'global-ua') {
        if (value != null &&
            (value is! String ||
                utf8.encode(value).length > 2048 ||
                _lineBreak.hasMatch(value))) {
          _invalid(key);
        }
      } else if (key == 'hosts') {
        if (value is! Map<String, Object?> || value.length > 128) {
          _invalid(key);
        }
        for (final entry in value.entries) {
          if (entry.key.isEmpty ||
              utf8.encode(entry.key).length > 255 ||
              entry.value is! String ||
              utf8.encode(entry.value! as String).length > 2048 ||
              _lineBreak.hasMatch('${entry.key}${entry.value}')) {
            _invalid(key);
          }
        }
      }
    }
    if (changes.keys.any(ipingPortKeys.contains)) {
      final ports = {...values, ...changes};
      final used = <int>{};
      for (final key in ipingPortKeys) {
        final value = (ports[key] as num?)?.toInt() ?? 0;
        if (value != 0 && !used.add(value)) {
          throw IpingSettingsException(key, IpingSettingsIssue.portConflict);
        }
      }
    }
  }
}

final _lineBreak = RegExp(r'[\x00\r\n]');

Never _invalid(String key) =>
    throw IpingSettingsException(key, IpingSettingsIssue.invalid);

Object? _freeze(Object? value) => switch (value) {
  final Map value => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries)
      entry.key as String: _freeze(entry.value),
  }),
  final List value => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
