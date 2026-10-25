import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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
    r'(ios-arm64\.ipa|openwrt-(?:24\.10|25\.12)-[A-Za-z0-9_-]+\.zip)$',
  ).firstMatch(name);
  return match == null ? null : p.basenameWithoutExtension(match[1]!);
}

Future<Map<String, Object>> buildUpdateManifest({
  required Directory artifacts,
  required Directory output,
  required String version,
  required int buildNumber,
  required Uri baseUrl,
  String notes = '',
  bool requireComplete = true,
}) async {
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
      buildNumber <= 0 ||
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
    final installer = name == 'install-openwrt.sh';
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
      downloads[download ?? 'openwrt-installer'] = metadata;
      if (installer) {
        await destination.copy(p.join(output.path, name));
      }
    }
  }
  final missing = updateTargets.difference(assets.keys.toSet());
  if (assets.isEmpty || (requireComplete && missing.isNotEmpty)) {
    throw StateError('Missing update artifacts: ${missing.join(', ')}');
  }
  final manifest = <String, Object>{
    'schemaVersion': 1,
    'packageId': 'my.iping.client',
    'version': version,
    'buildNumber': buildNumber,
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
    ..addOption('output', defaultsTo: 'build/update-release')
    ..addOption('base-url', defaultsTo: 'https://video.iping.my/releases/')
    ..addFlag('allow-partial', negatable: false);
  final options = parser.parse(args);
  final pubspec =
      loadYaml(await File('pubspec.yaml').readAsString()) as YamlMap;
  final parts = (pubspec['version'] as String).split('+');
  final changelog =
      jsonDecode(await File('changelog.json').readAsString())
          as Map<String, dynamic>;
  final versions = changelog['versions'] as List<dynamic>? ?? [];
  final notes = <String>[];
  for (final dynamic item in versions) {
    if (item['version'] != parts.first) continue;
    for (final dynamic group in item['groups'] as List) {
      for (final dynamic entry in group['entries'] as List) {
        notes.add('• ${entry['text']}');
      }
    }
  }
  final manifest = await buildUpdateManifest(
    artifacts: Directory(options['artifacts'] as String),
    output: Directory(options['output'] as String),
    version: parts.first,
    buildNumber: int.parse(parts[1]),
    baseUrl: Uri.parse(options['base-url'] as String),
    notes: notes.join('\n'),
    requireComplete: !options['allow-partial'],
  );
  stdout.writeln(
    'Prepared ${(manifest['assets'] as Map).length} update artifacts for ${parts.join('+')}',
  );
}
