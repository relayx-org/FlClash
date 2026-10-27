import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'src/changelog/builder.dart';

const updateTargets = {
  'android-arm-apk',
  'android-arm64-apk',
  'android-amd64-apk',
  'windows-amd64-exe',
  'macos-amd64-zip',
  'macos-arm64-zip',
  'linux-amd64-zip',
  'linux-amd64-deb',
  'linux-amd64-rpm',
  'linux-amd64-AppImage',
};

const releaseDownloads = {
  'ios-arm64',
  'windows-amd64-zip',
  'macos-amd64-dmg',
  'macos-arm64-dmg',
  'linux-agent-x86_64',
  'linux-agent-aarch64',
  'linux-agent-armv7',
  'linux-agent-mips',
  'linux-agent-mipsel',
  'linux-agent-installer',
};

String? updateArtifactTarget(String name, String version) {
  final match = RegExp(
    '^iPing-${RegExp.escape(version)}-'
    r'(android|windows|macos|linux)-(arm64-v8a|armeabi-v7a|x86_64|amd64|arm64)(?:-setup)?\.(apk|exe|zip|deb|rpm|AppImage)$',
  ).firstMatch(name);
  if (match == null) return null;
  final arch = switch (match[2]!) {
    'arm64-v8a' => 'arm64',
    'armeabi-v7a' => 'arm',
    'x86_64' => 'amd64',
    final value => value,
  };
  return '${match[1]}-$arch-${match[3]}';
}

String? downloadArtifactTarget(String name, String version) {
  final match = RegExp(
    '^iPing-${RegExp.escape(version)}-'
    r'(ios-arm64\.ipa|windows-amd64\.zip|macos-(?:amd64|arm64)\.dmg|linux-agent-(?:x86_64|aarch64|armv7|mips|mipsel)\.zip)$',
  ).firstMatch(name);
  if (match == null) return null;
  final target = p.basenameWithoutExtension(match[1]!);
  if (match[1]!.endsWith('.dmg')) return '$target-dmg';
  if (match[1]!.startsWith('windows-')) return '$target-zip';
  return target;
}

Future<Map<String, Object>> buildUpdateManifest({
  required Directory artifacts,
  required Directory output,
  required String version,
  required int buildNumber,
  required Uri baseUrl,
  String notes = '',
  String sourceCommit = '',
  bool requireComplete = true,
}) async {
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
      buildNumber <= 0 ||
      (sourceCommit.isNotEmpty &&
          !RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceCommit)) ||
      baseUrl.scheme != 'https' ||
      !baseUrl.path.endsWith('/')) {
    throw const FormatException(
      'Expected a stable version, positive build number and HTTPS base URL ending in /',
    );
  }
  final folder = '$version+$buildNumber';
  final assets = <String, Object>{};
  final downloads = <String, Object>{};
  final names = <String>{};
  await for (final entity in artifacts.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final target = updateArtifactTarget(name, version);
    final update = target != null && updateTargets.contains(target);
    final download = downloadArtifactTarget(name, version);
    final installer = name == 'install-linux.sh';
    if (!update && download == null && !installer) continue;
    if (!names.add(name)) throw StateError('Duplicate release artifact: $name');
    if (update && assets.containsKey(target)) {
      throw StateError('Duplicate update artifact: $target');
    }
    final destination = File(p.join(output.path, folder, name));
    await destination.parent.create(recursive: true);
    await entity.copy(destination.path);
    final size = await destination.length();
    if (size == 0) throw StateError('Empty update artifact: $name');
    final metadata = {
      'url': baseUrl.resolve('$folder/$name').toString(),
      'size': size,
      'sha256': (await sha256.bind(destination.openRead()).first).toString(),
      'format': p.extension(name).substring(1),
    };
    if (update) {
      assets[target] = metadata;
    } else {
      downloads[download ?? 'linux-agent-installer'] = metadata;
      if (installer) {
        await destination.copy(p.join(output.path, name));
      }
    }
  }
  final missing = {
    ...updateTargets.difference(assets.keys.toSet()),
    ...releaseDownloads.difference(downloads.keys.toSet()),
  };
  if (assets.isEmpty || (requireComplete && missing.isNotEmpty)) {
    throw StateError('Missing update artifacts: ${missing.join(', ')}');
  }
  final manifest = <String, Object>{
    'schemaVersion': 1,
    'packageId': 'my.iping.client',
    'version': version,
    'buildNumber': buildNumber,
    if (sourceCommit.isNotEmpty) 'sourceCommit': sourceCommit,
    'notes': notes,
    'assets': assets,
    'downloads': downloads,
  };
  await File(
    p.join(output.path, 'latest.json'),
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  return manifest;
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('artifacts', defaultsTo: 'dist')
    ..addOption(
      'source-commit',
      defaultsTo: Platform.environment['RELEASE_SHA'] ?? '',
    )
    ..addOption('output', defaultsTo: 'build/update-release')
    ..addOption('base-url', defaultsTo: 'https://video.iping.my/releases/')
    ..addFlag('allow-partial', negatable: false);
  final options = parser.parse(args);
  final pubspec =
      loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
  final parts = (pubspec['version'] as String).split('+');
  final release = changelogVersionFor(
    readChangelog(Directory.current.path),
    parts.first,
  );
  final notes = [
    for (final group in release.groups)
      for (final entry in group.entries) '• ${entry.text}',
  ];
  final manifest = await buildUpdateManifest(
    artifacts: Directory(options['artifacts'] as String),
    output: Directory(options['output'] as String),
    version: parts.first,
    buildNumber: int.parse(parts[1]),
    baseUrl: Uri.parse(options['base-url'] as String),
    notes: notes.join('\n'),
    sourceCommit: options['source-commit'] as String,
    requireComplete: !options['allow-partial'],
  );
  stdout.writeln(
    'Prepared ${(manifest['assets'] as Map).length} update artifacts for ${parts.join('+')}',
  );
}
