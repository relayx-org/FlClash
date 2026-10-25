import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:yaml/yaml.dart';
import '../common/indexing.dart';
import '../common/snowflake.dart';
import '../enum/rule_action.dart';
import '../enum/rule_target.dart';
import '../enum/rule_payload_error.dart';

export '../enum/rule_action.dart';
export '../enum/rule_target.dart';
export '../enum/rule_payload_error.dart';

part 'generated/rule.freezed.dart';
part 'generated/rule.g.dart';

@freezed
abstract class Rule with _$Rule {
  const factory Rule({
    @Default(-1) int id,
    @JsonKey(includeFromJson: false, includeToJson: false) int? profileId,
    @Default(RuleAction.DOMAIN) RuleAction ruleAction,
    String? content,
    String? ruleTarget,
    String? ruleProvider,
    String? subRule,
    @Default(false) bool noResolve,
    @Default(false) bool src,
    String? order,
  }) = _Rule;

  factory Rule.init() {
    return Rule(
      ruleAction: RuleAction.DOMAIN,
      ruleTarget: RuleTarget.DIRECT.value,
    );
  }

  // Mirrors mihomo's ParseRulePayload with needTarget set.
  factory Rule.parse(String value, {int? id}) {
    id ??= snowflake.id;
    final fields = value.split(',').map((item) => item.trim()).toList();
    final type = fields.first.toUpperCase();
    if (type.isEmpty) {
      return Rule(
        id: id,
        ruleAction: RuleAction.DOMAIN,
        ruleTarget: RuleTarget.DIRECT.value,
      );
    }
    final action = RuleAction.values.firstWhere(
      (item) => item.value == type,
      orElse: () => RuleAction.DOMAIN,
    );
    final rest = fields.sublist(1);
    String? payload;
    String? target;
    var params = const <String>[];
    if (action == RuleAction.MATCH) {
      target = rest.firstOrNull;
    } else if (action.hasCommaPayload) {
      target = rest.lastOrNull;
      payload = rest.length > 1
          ? rest.sublist(0, rest.length - 1).join(',')
          : null;
    } else {
      payload = rest.elementAtOrNull(0);
      target = rest.elementAtOrNull(1);
      params = rest.skip(2).toList();
    }
    payload = payload?.isNotEmpty == true ? payload : null;
    target = target?.isNotEmpty == true ? target : null;

    return Rule(
      id: id,
      ruleAction: action,
      content: action == RuleAction.RULE_SET ? null : payload,
      ruleProvider: action == RuleAction.RULE_SET ? payload : null,
      ruleTarget: action == RuleAction.SUB_RULE ? null : target,
      subRule: action == RuleAction.SUB_RULE ? target : null,
      src: params.contains('src'),
      noResolve: params.contains('no-resolve'),
    );
  }

  factory Rule.fromJson(Map<String, Object?> json) => _$RuleFromJson(json);
}

extension RuleExt on Rule {
  Rule autoOrder(Rule rule, String? a, String? b) {
    final newRule = rule.order?.isNotEmpty != true
        ? rule.copyWith(order: indexing.generateKeyBetween(a, b))
        : rule;
    return newRule;
  }

  String? get realContent {
    return switch (ruleAction) {
      RuleAction.MATCH => null,
      RuleAction.RULE_SET => ruleProvider,
      _ => content,
    };
  }

  String? get realTarget {
    return switch (ruleAction == RuleAction.SUB_RULE) {
      true => subRule,
      false => ruleTarget,
    };
  }

  String? targetErrorTip(String invalidSubRuleTip, String invalidPolicyTip) {
    return switch (ruleAction == RuleAction.SUB_RULE) {
      true => invalidSubRuleTip,
      false => invalidPolicyTip,
    };
  }

  /// The core rejects the whole config over one of these, taking the profile
  /// down with it, so they are caught before the rule can be saved.
  RulePayloadError? get payloadError {
    final payload = realContent?.trim() ?? '';
    if (payload.isEmpty) {
      return null;
    }
    switch (ruleAction) {
      case RuleAction.NETWORK:
        return const ['tcp', 'udp'].contains(payload.toLowerCase())
            ? null
            : RulePayloadError.network;
      case RuleAction.DST_PORT:
      case RuleAction.SRC_PORT:
      case RuleAction.IN_PORT:
      case RuleAction.UID:
        return _parseRanges(payload) == null
            ? RulePayloadError.numberRange
            : null;
      case RuleAction.DSCP:
        final bounds = _parseRanges(payload);
        if (bounds == null) {
          return RulePayloadError.numberRange;
        }
        return bounds.every((item) => item <= 63)
            ? null
            : RulePayloadError.dscpRange;
      default:
        return null;
    }
  }

  String get rawValue {
    final content = realContent;
    final target = realTarget;
    return [
      ruleAction.value,
      if (content?.isNotEmpty == true) content!,
      if (target?.isNotEmpty == true) target!,
      if (ruleAction.hasParams) ...[
        if (src) 'src',
        if (noResolve) 'no-resolve',
      ],
    ].join(',');
  }

  List<String> get searchFields => [ruleAction.name, rawValue];
}

final class RuleLineException implements Exception {
  final int line;

  const RuleLineException(this.line);
}

String encodeRuleList(Iterable<Rule> rules) {
  return rules.map((rule) => '- ${_ruleScalar(rule.rawValue)}\n').join();
}

String _ruleScalar(String value) {
  if (!value.contains(': ') && !value.contains(' #') && !value.endsWith(':')) {
    return value;
  }
  return "'${value.replaceAll("'", "''")}'";
}

final _rulesHeader = RegExp(r'^rules\s*[:：]$', caseSensitive: false);

List<({int line, Rule rule})> decodeRuleList(
  String content, {
  Iterable<Rule> previous = const [],
}) {
  final unusedIds = <String, List<int>>{};
  for (final rule in previous) {
    unusedIds.putIfAbsent(rule.rawValue, () => []).add(rule.id);
  }
  return [
    for (final (index, line) in content.split('\n').indexed)
      if (line.trim() case final text
          when text.isNotEmpty &&
              !text.startsWith('#') &&
              !_rulesHeader.hasMatch(text))
        (line: index + 1, rule: _ruleAt(_ruleText(text), index + 1, unusedIds)),
  ];
}

String _ruleText(String line) {
  final text = line.startsWith('-') ? line.substring(1).trimLeft() : line;
  if (text.startsWith("'") || text.startsWith('"')) {
    return switch (_loadScalar(text)) {
      final String value => value,
      _ => text,
    };
  }
  final comment = text.indexOf(' #');
  return comment < 0 ? text : text.substring(0, comment).trimRight();
}

Object? _loadScalar(String text) {
  try {
    return loadYaml(text);
  } on YamlException {
    return null;
  }
}

Rule _ruleAt(String value, int line, Map<String, List<int>> unusedIds) {
  final type = value.split(',').first.trim().toUpperCase();
  if (!RuleAction.values.any((action) => action.value == type)) {
    throw RuleLineException(line);
  }
  final rule = Rule.parse(value);
  final ids = unusedIds[rule.rawValue];
  return ids == null || ids.isEmpty ? rule : rule.copyWith(id: ids.removeAt(0));
}

/// Mirrors mihomo's newIntRanges: `80`, `80-90`, and `/` or `,` between them.
List<int>? _parseRanges(String payload) {
  if (payload == '*') {
    return null;
  }
  final segments = payload.replaceAll(',', '/').split('/');
  if (segments.length > 28) {
    return null;
  }
  final bounds = <int>[];
  for (final segment in segments) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final parts = trimmed.split('-');
    if (parts.length > 2) {
      return null;
    }
    for (final part in parts) {
      final bound = int.tryParse(part.replaceAll(RegExp(r'[\[\] ]'), ''));
      if (bound == null || bound < 0) {
        return null;
      }
      bounds.add(bound);
    }
  }
  return bounds.isEmpty ? null : bounds;
}
