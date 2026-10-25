import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/javascript.dart';
import 'package:fl_clash/iping/backend_resources.dart';
import 'package:fl_clash/iping/profile_resources.dart';
import 'package:fl_clash/iping/profile_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../plugins/code_forge/support.dart' show initEditorNative;

void main() {
  setUpAll(initEditorNative);

  test('native and Agent share the profile extension contract', () async {
    final fixture =
        jsonDecode(
              await File(
                'test/fixtures/iping_profile_resources.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final values = fixture['values'] as Map<String, dynamic>;
    final bindings = IpingResourceBindings.fromJson(
      values['custom.bindings'] as Map<String, dynamic>,
    );
    final scripts = (values['custom.scripts'] as List).map(
      (item) => IpingScript.fromJson(Map<String, Object?>.from(item as Map)),
    );
    final script = scripts.singleWhere((item) => item.id == bindings.script);
    var config = await handleEvaluate(
      script.content,
      fixture['source'] as Map<String, dynamic>,
    );
    config = applyIpingProfileResources(
      config,
      proxies: [
        for (final item in values['custom.proxies'] as List)
          if (bindings.proxies.contains(item['id']))
            Map<String, dynamic>.from(item['definition'] as Map),
      ],
      filters: [
        for (final item in values['custom.filters'] as List)
          if (bindings.filters.contains(item['label']))
            Filter.fromJson(Map<String, Object?>.from(item as Map)),
      ],
    );
    config['rules'] =
        prependIpingRules(List<String>.from(config['rules'] as List), [
          for (final item in values['custom.rules'] as List)
            if (bindings.rules.contains(item['id']))
              IpingAddedRule.fromJson(
                Map<String, Object?>.from(item as Map),
              ).rule,
        ]);
    expect(config, fixture['expected']);
    final rule = IpingAddedRule.fromJson(
      Map<String, Object?>.from((values['custom.rules'] as List).single as Map),
    );
    expect(rule.toJson(), (values['custom.rules'] as List).single);
  });

  test(
    'resource application rejects collisions and does not modify the source',
    () {
      final source = <String, dynamic>{
        'proxies': [
          {'name': 'Home', 'type': 'direct'},
        ],
      };
      expect(
        () => applyIpingProfileResources(
          source,
          proxies: const [
            {'name': 'Home', 'type': 'ss'},
          ],
          filters: const [],
        ),
        throwsA(isA<IpingResourceException>()),
      );
      expect(
        () => applyIpingProfileResources(
          source,
          proxies: const [],
          filters: const [Filter(label: 'Home', regex: 'hk')],
        ),
        throwsA(isA<IpingResourceException>()),
      );
      expect((source['proxies'] as List).length, 1);
      expect(
        () => validateIpingResourceBindings(
          const IpingResourceBindings(script: 'gone'),
          proxies: {},
          providers: {},
          filters: {},
        ),
        throwsA(isA<IpingResourceException>()),
      );
    },
  );
}
