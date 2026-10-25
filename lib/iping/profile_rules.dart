import '../models/rule.dart';

List<String> prependIpingRules(
  List<String> rules,
  List<Rule> additions, {
  String? matchTarget,
}) {
  if (additions.isEmpty) return rules;
  var target = matchTarget?.trim();
  if (target == null || target.isEmpty) {
    for (final value in rules.reversed) {
      final parts = value.split(',');
      if (parts.length >= 2 && parts.first.trim().toUpperCase() == 'MATCH') {
        target = parts[1].trim();
        break;
      }
    }
  }
  return [
    for (final item in additions)
      item.ruleTarget?.trim().toUpperCase() == 'MATCH' &&
              target?.isNotEmpty == true
          ? item.copyWith(ruleTarget: target).rawValue
          : item.rawValue,
    ...rules,
  ];
}
