// ignore_for_file: constant_identifier_names

enum RuleTarget {
  DIRECT('DIRECT'),
  REJECT('REJECT'),
  REJECT_DROP('REJECT-DROP'),
  PASS('PASS'),
  PASS_RULE('PASS-RULE'),
  COMPATIBLE('COMPATIBLE');

  final String value;

  const RuleTarget(this.value);

  static final List<String> baseTargetNames = List.unmodifiable(
    RuleTarget.values.map((item) => item.value),
  );

  static final Set<String> baseTargets = Set.unmodifiable(baseTargetNames);

  /// GLOBAL is created after group parsing, so groups cannot reference it.
  static final List<String> ruleTargetNames = List.unmodifiable([
    ...baseTargetNames,
    'GLOBAL',
  ]);

  static final Set<String> ruleTargets = Set.unmodifiable(ruleTargetNames);
}
