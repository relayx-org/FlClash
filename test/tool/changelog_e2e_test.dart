import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/src/changelog/builder.dart';
import '../../tool/src/changelog/render.dart';

void main() {
  late Directory directory;
  late File source;
  late File markdown;
  final script = File('tool/changelog.dart').absolute.path;
  const history = '## v0.8.96 (2026-08-17)\n\n- 修复历史版本的问题\n';

  ProcessResult run(List<String> arguments) =>
      Process.runSync('dart', [script, '--root', directory.path, ...arguments]);

  void succeeds(List<String> arguments) {
    final result = run(arguments);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('flclash-changelog-');
    source = File('${directory.path}/changelog.json')
      ..writeAsStringSync(
        jsonEncode({
          'schemaVersion': 2,
          'versions': [
            {
              'version': '1.2.3',
              'prerelease': true,
              'groups': [
                {
                  'type': 'feat',
                  'entries': [
                    {'text': '无需登录即可导入订阅'},
                  ],
                },
              ],
            },
          ],
        }),
      );
    markdown = File('${directory.path}/CHANGELOG.md')
      ..writeAsStringSync('# 更新日志\n\n$changelogFrozenMarker\n\n$history');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('build and verify use authored notes without a Git repository', () {
    final authored = source.readAsStringSync();
    succeeds(['build']);
    succeeds(['verify', '--version', '1.2.3']);
    expect(Directory('${directory.path}/.git').existsSync(), isFalse);
    expect(source.readAsStringSync(), authored);
    expect(markdown.readAsStringSync(), contains('**新增功能**\n\n- 无需登录即可导入订阅'));
    expect(markdown.readAsStringSync(), endsWith(history));
    final first = markdown.readAsStringSync();
    succeeds(['build']);
    expect(markdown.readAsStringSync(), first);
  });

  test('release only finalizes an existing version and preserves its copy', () {
    succeeds(['release', '--version', '1.2.3', '--date', '2026-10-27']);
    final release = readChangelog(directory.path).versions.single;
    expect(release.prerelease, isFalse);
    expect(release.date, '2026-10-27');
    expect(release.groups.single.entries.single.text, '无需登录即可导入订阅');
    expect(release.groups.single.entries.single.id, isEmpty);
    succeeds(['verify', '--version', 'v1.2.3']);
  });

  test('renderers use the selected authored version', () {
    final authored = source.readAsStringSync();
    succeeds(['render', 'release', '--tag', 'v1.2.3', '--out', 'release.md']);
    final body = File('${directory.path}/release.md').readAsStringSync();
    expect(body, contains('### 新增功能\n- 无需登录即可导入订阅'));
    expect(body, contains('"id":"1.2.3-feat-1"'));
    final telegram = run(['render', 'telegram', '--tag', '1.2.3']);
    expect(telegram.exitCode, 0);
    expect(telegram.stdout, '<b>新增功能</b>\n• 无需登录即可导入订阅');
    expect(source.readAsStringSync(), authored);
  });

  test('missing version fails before changing either source file', () {
    final authored = source.readAsStringSync();
    final existing = markdown.readAsStringSync();
    for (final arguments in [
      ['release', '--version', '1.2.4'],
      ['render', 'release', '--tag', 'v1.2.4'],
      ['verify', '--version', '1.2.4'],
    ]) {
      final result = run(arguments);
      expect(result.exitCode, 64);
      expect(result.stderr, contains('Add release notes for'));
    }
    expect(source.readAsStringSync(), authored);
    expect(markdown.readAsStringSync(), existing);
  });

  test('verify detects stale Markdown after independently editing notes', () {
    succeeds(['build']);
    source.writeAsStringSync(
      source.readAsStringSync().replaceAll('无需登录即可导入订阅', '手动导入任意订阅链接'),
    );
    final result = run(['verify']);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('does not match'));
    succeeds(['build']);
    succeeds(['verify']);
    expect(markdown.readAsStringSync(), contains('手动导入任意订阅链接'));
  });

  test('validation rejects malformed release metadata and empty copy', () {
    final authored =
        jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
    final version = (authored['versions'] as List).single as Map;
    final group = (version['groups'] as List).single as Map;
    final entry = (group['entries'] as List).single as Map;

    void rejects(String problem) {
      source.writeAsStringSync(jsonEncode(authored));
      expect(() => readChangelog(directory.path), throwsFormatException);
      final result = run(['build']);
      expect(result.exitCode, 64);
      expect(result.stderr, contains(problem));
    }

    version['date'] = '2026-02-30';
    rejects('Invalid release date');
    version.remove('date');
    (authored['versions'] as List).add(version);
    rejects('Duplicate release');
    (authored['versions'] as List).removeLast();
    group['type'] = 'unknown';
    rejects('Unknown changelog group');
    group['type'] = 'feat';
    entry['text'] = '  ';
    rejects('Empty release note');
  });

  test('unsupported schema fails rather than replacing authored notes', () {
    source.writeAsStringSync('{"schemaVersion": 99, "versions": []}');
    final existing = markdown.readAsStringSync();
    final result = run(['build']);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Unsupported changelog schema'));
    expect(markdown.readAsStringSync(), existing);
  });

  test('malformed authored data reports a validation error', () {
    source.writeAsStringSync('{"schemaVersion": 2, "versions": [{}]}');
    final result = run(['build']);
    expect(result.exitCode, 64);
    expect(result.stderr, contains('Invalid structure'));
  });

  test(
    'update manifests require the app version and use its authored copy',
    () {
      final artifacts = Directory('${directory.path}/dist')..createSync();
      File(
        '${artifacts.path}/iPing-1.2.3-macos-arm64.zip',
      ).writeAsBytesSync([1, 2, 3]);
      final pubspec = File('${directory.path}/pubspec.yaml')
        ..writeAsStringSync('version: 1.2.3+42\n');
      final manifestScript = File('tool/update_manifest.dart').absolute.path;

      ProcessResult prepare() => Process.runSync('dart', [
        manifestScript,
        '--allow-partial',
      ], workingDirectory: directory.path);

      final result = prepare();
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final manifest = File(
        '${directory.path}/build/update-release/latest.json',
      );
      final payload = jsonDecode(manifest.readAsStringSync()) as Map;
      expect(payload['notes'], '• 无需登录即可导入订阅');
      expect(payload['version'], '1.2.3');
      expect(payload['buildNumber'], 42);

      pubspec.writeAsStringSync('version: 1.2.4+43\n');
      manifest.deleteSync();
      final missing = prepare();
      expect(missing.exitCode, isNot(0));
      expect(missing.stderr, contains('Add release notes for 1.2.4'));
      expect(manifest.existsSync(), isFalse);
    },
  );
}
