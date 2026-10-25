import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final root = p.dirname(p.dirname(Platform.script.toFilePath()));
  final cache = Directory(p.join(root, '.dart_tool', 'ios_core'));
  await cache.create(recursive: true);
  final lock = await File(
    p.join(cache.path, 'build.lock'),
  ).open(mode: FileMode.append);
  await lock.lock(FileLock.blockingExclusive);
  try {
    await _build(root, cache);
  } finally {
    await lock.close();
  }
}

Future<void> _build(String root, Directory cache) async {
  final configFile = File(p.join(root, 'build_config.yaml'));
  final config = loadYaml(await configFile.readAsString()) as Map;
  final core = p.join(root, config['core_dir'] as String? ?? 'core');
  final framework = p.join(root, 'libclash', 'ios', 'Clash.xcframework');
  final paths = <String>[configFile.path, Platform.script.toFilePath()];
  await for (final entity in Directory(core).list(recursive: true)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if ((name.endsWith('.go') && !name.endsWith('_test.go')) ||
        name == 'go.mod' ||
        name == 'go.sum') {
      paths.add(entity.path);
    }
  }
  paths.sort();
  Stream<List<int>> inputs() async* {
    for (final path in paths) {
      yield utf8.encode(p.relative(path, from: root));
      yield* File(path).openRead();
    }
    for (final command in [
      ['go', 'version'],
      ['xcodebuild', '-version'],
    ]) {
      yield utf8.encode(await _run(command.first, command.sublist(1), core));
    }
  }

  final key = (await sha256.bind(inputs()).single).toString();
  final stamp = File(p.join(cache.path, 'fingerprint'));
  if (await stamp.exists() &&
      await stamp.readAsString() == key &&
      await File(p.join(framework, 'Info.plist')).exists()) {
    stdout.writeln('iOS Core is up to date');
    return;
  }
  final tools = Directory(p.join(cache.path, 'bin'));
  await tools.create(recursive: true);
  for (final tool in ['gobind', 'gomobile']) {
    await _run('go', [
      'build',
      '-o',
      p.join(tools.path, tool),
      'golang.org/x/mobile/cmd/$tool',
    ], core);
  }
  final defaults = (await _run('go', [
    'list',
    '-f',
    '{{.DefaultGODEBUG}}',
    './cmd/core',
  ], core)).trim();
  final output = p.join(cache.path, 'Clash.xcframework');
  final tags = [config['tags'] ?? 'with_gvisor', 'with_low_memory'].join(',');
  final ldflags = [
    config['go_ldflags'] ?? '-w -s',
    '-X=runtime.godebugDefault=$defaults',
    '-X=github.com/metacubex/mihomo/constant.Version=${config['core_version'] ?? ''}',
  ].join(' ');
  stdout.writeln('Building the iOS device and simulator Core frameworks');
  await _run(
    p.join(tools.path, 'gomobile'),
    [
      'bind',
      '-target=ios,iossimulator',
      '-iosversion=15.0',
      '-trimpath',
      '-tags=$tags',
      '-ldflags=$ldflags',
      '-o',
      output,
      './mobile',
    ],
    core,
    environment: {
      'PATH': '${tools.path}:${Platform.environment['PATH'] ?? ''}',
    },
  );
  final destination = Directory(framework);
  await destination.parent.create(recursive: true);
  if (await destination.exists()) await destination.delete(recursive: true);
  await Directory(output).rename(framework);
  await stamp.writeAsString(key, flush: true);
}

Future<String> _run(
  String command,
  List<String> arguments,
  String directory, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    command,
    arguments,
    workingDirectory: directory,
    environment: {
      'PATH':
          '${Platform.environment['PATH'] ?? ''}:/opt/homebrew/bin:/usr/local/bin:/usr/local/go/bin',
      ...?environment,
    },
  );
  if (result.exitCode != 0) {
    stderr.write(result.stdout);
    stderr.write(result.stderr);
    throw ProcessException(command, arguments, 'iOS Core build failed');
  }
  return result.stdout.toString();
}
