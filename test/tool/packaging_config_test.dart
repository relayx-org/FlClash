import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('MinIO publication waits for iOS and the same-source Linux Agent', () {
    final build =
        loadYaml(File('.github/workflows/build.yaml').readAsStringSync())
            as YamlMap;
    final jobs = build['jobs'] as YamlMap;
    final native = jobs['build'] as YamlMap;
    final matrix =
        jsonDecode(
              File('tool/ci/native_targets.json').readAsStringSync(),
            )['include']
            as List;
    expect(
      native['strategy']['matrix'],
      r'${{ fromJSON(needs.plan.outputs.matrix) }}',
    );
    final ios =
        matrix.singleWhere((entry) => entry['platform'] == 'ios') as Map;
    expect(ios['arch'], 'arm64');
    expect(ios['runner'], contains('macOS'));
    final signing = (native['steps'] as YamlList).singleWhere(
      (step) => step['name'] == 'Prepare iOS distribution signing',
    );
    expect(
      signing['env'].keys,
      containsAll([
        'IOS_CERTIFICATE',
        'IOS_CERTIFICATE_PASSWORD',
        'IOS_PROVISIONING_PROFILE',
        'IOS_TUNNEL_PROVISIONING_PROFILE',
      ]),
    );
    expect(jobs['linux-agent']['uses'], './.github/workflows/linux-agent.yaml');
    expect(
      jobs['linux-agent']['with']['ref'],
      r'${{ needs.release.outputs.sha }}',
    );
    expect(jobs, isNot(contains('upload')));
    expect(
      File('.github/workflows/build.yaml').readAsStringSync(),
      isNot(contains('actions/upload-artifact')),
    );
    expect(
      File('.github/workflows/build.yaml').readAsStringSync(),
      isNot(contains('actions/download-artifact')),
    );
    expect(
      jobs['publish-minio']['needs'],
      containsAll(['build', 'linux-agent']),
    );
    final workflow =
        loadYaml(File('.github/workflows/linux-agent.yaml').readAsStringSync())
            as YamlMap;
    expect(workflow['on']['workflow_call']['inputs'], contains('ref'));
    for (final job in (workflow['jobs'] as YamlMap).values) {
      final checkout = (job['steps'] as YamlList).firstWhere(
        (step) => step['uses'] == 'actions/checkout@v4',
      );
      expect(checkout['with']['ref'], r'${{ inputs.ref || github.sha }}');
    }
  });

  group('Linux packaging teardown', () {
    for (final format in ['deb', 'rpm']) {
      test('$format removes the Helper unit only on a real uninstall', () {
        final config =
            loadYaml(
                  File(
                    'linux/packaging/$format/make_config.yaml',
                  ).readAsStringSync(),
                )
                as YamlMap;
        final scripts = (config['postuninstall_scripts'] as YamlList)
            .cast<String>();

        expect(scripts.first, contains('exit 0'));
        expect(
          scripts,
          contains('rm -f /etc/systemd/system/iping-helper.service'),
        );
        expect(
          scripts.any((script) => script.contains('systemctl daemon-reload')),
          isTrue,
        );
      });
    }
  });

  test('every Linux package names the GTK application id as its window '
      'class', () {
    final applicationId = RegExp(
      r'set\(APPLICATION_ID "([^"]+)"\)',
    ).firstMatch(File('linux/CMakeLists.txt').readAsStringSync())!.group(1);

    for (final format in ['deb', 'rpm', 'appimage']) {
      final config =
          loadYaml(
                File(
                  'linux/packaging/$format/make_config.yaml',
                ).readAsStringSync(),
              )
              as YamlMap;
      expect(config['startup_wm_class'], applicationId, reason: format);
    }
  });

  test('rpm keeps the Core bytes the Helper was built against', () {
    final config =
        loadYaml(
              File('linux/packaging/rpm/make_config.yaml').readAsStringSync(),
            )
            as YamlMap;
    final macros = (config['spec_macros'] as YamlList).cast<String>();

    expect(macros, contains('%global debug_package %{nil}'));
    expect(macros, contains('%global __os_install_post %{nil}'));
  });
}
