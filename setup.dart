import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'tool/package_ios.dart';

const _allTargets = <String, String>{
  'android': 'apk',
  'ios': 'ipa',
  'linux': 'deb,appimage,rpm,zip',
  'macos': 'dmg,zip',
  'windows': 'exe,zip',
};

const _androidFlutterTarget = {
  'arm': 'android-arm',
  'arm64': 'android-arm64',
  'amd64': 'android-x64',
};

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

const _distributorRepository =
    'https://github.com/chen08209/flutter_distributor.git';
const _distributorRef = 'v0.6.11-flclash.3';

Future<void> main(List<String> args) async {
  final parser = createSetupArgParser();

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem;
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;

  if (!canBuildPlatform(platform, host)) {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: $host, android${host == 'macos' ? ', ios' : ''}',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final rootDir = Directory.current.path;
  final pubspec = File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync();
  final skipped = packagesNotBuildingAssets(pubspec);
  if (skipped.isNotEmpty) {
    stderr.writeln(
      'pubspec.yaml sets hooks.user_defines.<package>.build_assets: false '
      'for ${skipped.join(', ')}; a package built this way would ship '
      'whatever is left in libclash/ and no Rust library. '
      'Restore "build_assets: true".',
    );
    exit(1);
  }
  final arch = packageArchitecture(platform, pubspec, _detectArch());
  final targets = createPackageTargets(platform, results['targets']);
  final androidArch = results['arch'] as String?;
  final verbose = results['verbose'] as bool;

  final exitCode = await _package(
    platform,
    env,
    targets,
    rootDir,
    arch,
    androidArch: androidArch,
    verbose: verbose,
  );
  exit(exitCode);
}

ArgParser createSetupArgParser() {
  return ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['dev', 'pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    )
    ..addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      allowed: ['arm', 'arm64', 'amd64'],
      help: 'Target architecture (Android only)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose Flutter build output',
    );
}

List<String> createFlutterBuildArgs({
  required String platform,
  required bool verbose,
}) {
  final flutterBuildArgs = <String>[
    if (verbose) 'verbose',
    'dart-define-from-file=env.json',
  ];
  if (platform == 'android') {
    flutterBuildArgs.add('split-per-abi');
  }
  return flutterBuildArgs;
}

Map<String, String> createBuildEnvironment(String env) {
  return {'APP_ENV': env};
}

bool canBuildPlatform(String platform, String host) =>
    platform == host ||
    platform == 'android' ||
    host == 'macos' && platform == 'ios';

String packageArchitecture(String platform, String pubspec, String host) {
  if (platform == 'ios') return 'arm64';
  if (platform != 'macos') return host;
  final document = loadYaml(pubspec) as Map;
  final defines = (document['hooks'] as Map?)?['user_defines'] as Map?;
  final architecture = (defines?['setup'] as Map?)?['macos_architecture'];
  return switch (architecture) {
    null => host,
    'amd64' || 'arm64' => architecture as String,
    _ => throw ArgumentError('Invalid macOS architecture: $architecture'),
  };
}

/// Packages whose build hook `pubspec.yaml` turns into a no-op.
List<String> packagesNotBuildingAssets(String pubspec) {
  final document = loadYaml(pubspec);
  if (document is! Map) return const [];
  final defines = (document['hooks'] as Map?)?['user_defines'];
  if (defines is! Map) return const [];
  return [
    for (final MapEntry(:key, :value) in defines.entries)
      if (value is Map && value['build_assets'] == false) key.toString(),
  ]..sort();
}

String createPackageTargets(String platform, String? customTargets) {
  if (platform == 'ios' && customTargets != null && customTargets != 'ipa') {
    throw ArgumentError('iOS only supports the ipa package target');
  }
  return customTargets ?? _allTargets[platform]!;
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln(
    'Platform: current host platform (default), android, or ios on macOS',
  );
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((p, t) => stderr.writeln('  $p: $t'));
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
  String arch, {
  String? androidArch,
  required bool verbose,
}) async {
  final file = File(p.join(rootDir, 'env.json'));
  await file.writeAsString(jsonEncode(createBuildEnvironment(env)));

  final flutterBuildArgs = createFlutterBuildArgs(
    platform: platform,
    verbose: verbose,
  );
  final descriptionArgs = <String>[];
  if (platform != 'android') {
    descriptionArgs.addAll(['--description', arch]);
  }

  final depExit = await _ensureDependencies(platform);
  if (depExit != 0) return depExit;

  if (platform == 'ios') {
    final exports = Directory(p.join(rootDir, 'build', 'ios', 'ipa'));
    final exportOptions = Platform.environment['EXPORT_OPTIONS_PLIST'];
    if (exportOptions != null &&
        exportOptions.isNotEmpty &&
        !await File(exportOptions).exists()) {
      throw ArgumentError('iOS export options do not exist: $exportOptions');
    }
    // Flutter can exit successfully when archive export fails.
    if (await exports.exists()) await exports.delete(recursive: true);
    final build = await Process.start(
      'flutter',
      createIosBuildArguments(
        flutterBuildArgs: flutterBuildArgs,
        exportOptionsPlist: exportOptions,
      ),
      workingDirectory: rootDir,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await build.exitCode;
    if (code != 0) return code;
    if (exportOptions != null && exportOptions.isNotEmpty) {
      await exportSignedIosArchive(
        rootDir: rootDir,
        exportOptionsPlist: exportOptions,
      );
    }
    final pubspec =
        loadYaml(await File(p.join(rootDir, 'pubspec.yaml')).readAsString())
            as Map;
    final options =
        loadYaml(
              await File(
                p.join(rootDir, 'distribute_options.yaml'),
              ).readAsString(),
            )
            as Map;
    final name = options['app_name'] as String;
    final version = (pubspec['version'] as String).split('+').first;
    await packageSignedIosIpa(
      exports: exports,
      output: File(
        p.join(
          rootDir,
          options['output'] as String,
          '$name-$version-ios-arm64.ipa',
        ),
      ),
    );
    return 0;
  }

  final patchedAppImage =
      platform == 'linux' && targets.split(',').contains('appimage');
  Directory? distributor;
  if (patchedAppImage) {
    distributor = await _prepareAppImageDistributor(rootDir);
  } else {
    final activateResult = await Process.run('dart', [
      'pub',
      'global',
      'activate',
      '-s',
      'git',
      _distributorRepository,
      '--git-ref',
      _distributorRef,
      '--git-path',
      'packages/flutter_distributor',
    ]);
    if (activateResult.exitCode != 0) {
      stderr.write(activateResult.stderr);
      return activateResult.exitCode;
    }
  }

  final distributionTargets = platform == 'macos'
      ? targets.split(',').where((target) => target != 'zip').join(',')
      : targets;
  late final int exitCode;
  try {
    final packageDir = distributor == null
        ? null
        : p.join(distributor.path, 'packages', 'flutter_distributor');
    final process = await Process.start(
      packageDir == null ? 'flutter_distributor' : 'dart',
      [
        if (packageDir != null) ...[
          '--packages=${p.join(packageDir, '.dart_tool', 'package_config.json')}',
          p.join(packageDir, 'bin', 'main.dart'),
        ],
        'package',
        '--skip-clean',
        if (platform == 'macos' &&
            Platform.environment['CODESIGN_IDENTITY']?.isNotEmpty == true)
          '--hook-pre=bash tool/sign_macos.sh',
        '--platform',
        platform,
        '--targets',
        distributionTargets.isEmpty ? 'dmg' : distributionTargets,
        if (androidArch != null)
          '--build-target-platform=${_androidFlutterTarget[androidArch]!}',
        if (flutterBuildArgs.isNotEmpty)
          '--flutter-build-args=${flutterBuildArgs.join(',')}',
        ...descriptionArgs,
      ],
      includeParentEnvironment: true,
      runInShell: Platform.isWindows,
    );

    process.stdout.listen((data) {
      stdout.write(utf8.decode(data));
    });
    process.stderr.listen((data) {
      stderr.write(utf8.decode(data));
    });
    exitCode = await process.exitCode;
  } finally {
    if (distributor != null) await distributor.delete(recursive: true);
  }
  if (exitCode == 0 &&
      platform == 'macos' &&
      targets.split(',').contains('zip')) {
    final options =
        loadYaml(
              await File(
                p.join(rootDir, 'distribute_options.yaml'),
              ).readAsString(),
            )
            as YamlMap;
    final pubspec =
        loadYaml(await File(p.join(rootDir, 'pubspec.yaml')).readAsString())
            as YamlMap;
    final name = options['app_name'] as String;
    final version = (pubspec['version'] as String).split('+').first;
    final output = Directory(p.join(rootDir, options['output'] as String));
    await output.create(recursive: true);
    final archive = File(p.join(output.path, '$name-$version-macos-$arch.zip'));
    if (await archive.exists()) await archive.delete();
    final result = await Process.run('/usr/bin/ditto', [
      '-c',
      '-k',
      '--sequesterRsrc',
      '--keepParent',
      p.join(rootDir, 'build/macos/Build/Products/Release/$name.app'),
      archive.path,
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      return result.exitCode;
    }
  }
  return exitCode;
}

Future<Directory> _prepareAppImageDistributor(String rootDir) async {
  final directory = await Directory.systemTemp.createTemp('iping-distributor-');
  try {
    await _runSetupCommand('git', [
      'clone',
      '--quiet',
      '--depth',
      '1',
      '--branch',
      _distributorRef,
      _distributorRepository,
      directory.path,
    ]);
    await _runSetupCommand('git', [
      'apply',
      '--unidiff-zero',
      p.join(rootDir, 'tool', 'patches', 'flutter-distributor-appimage.patch'),
    ], workingDirectory: directory.path);
    await _runSetupCommand(
      'dart',
      ['pub', 'get'],
      workingDirectory: p.join(
        directory.path,
        'packages',
        'flutter_distributor',
      ),
    );
    return directory;
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

Future<void> _runSetupCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

String _detectArch() {
  if (Platform.isWindows) {
    final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
    return pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
  }
  final result = Process.runSync('uname', ['-m']);
  final machine = (result.stdout as String).trim();
  if (machine == 'aarch64') return 'arm64';
  if (machine == 'x86_64') return 'amd64';
  return machine;
}

Future<bool> _hasCommand(String cmd) async {
  final which = Platform.isWindows ? 'where' : 'command';
  final args = Platform.isWindows ? [cmd] : ['-v', cmd];
  final result = await Process.run(which, args);
  return result.exitCode == 0;
}

Future<int> _ensureDependencies(String platform) async {
  switch (platform) {
    case 'macos':
      return _ensureMacosDependencies();
    case 'linux':
      return _ensureLinuxDependencies();
    default:
      return 0;
  }
}

Future<int> _ensureMacosDependencies() async {
  if (await _hasCommand('appdmg')) {
    stdout.writeln('appdmg already installed, skipping.');
    return 0;
  }
  stdout.writeln('Installing appdmg (DMG creator)...');
  final result = await Process.run('npm', ['install', '-g', 'appdmg']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}

Future<int> _ensureLinuxDependencies() async {
  const pkgGroups = <List<String>>[
    ['ninja-build', 'libgtk-3-dev'],
    ['libayatana-appindicator3-dev'],
    ['libsecret-1-dev'],
    ['locate'],
    ['rpm', 'patchelf'],
    ['libfuse2'],
  ];

  final missingGroups = <List<String>>[];
  for (final group in pkgGroups) {
    final missingPkgs = <String>[];
    for (final pkg in group) {
      if (!await _isDebianPackageInstalled(pkg)) {
        missingPkgs.add(pkg);
      }
    }
    if (missingPkgs.isNotEmpty) {
      missingGroups.add(missingPkgs);
    }
  }

  if (missingGroups.isEmpty) {
    stdout.writeln('All Linux build dependencies already installed, skipping.');
  } else {
    stdout.writeln('Updating apt package lists...');
    final updateExit = await _runLinuxDependencyCommand([
      'apt-get',
      'update',
      '-y',
    ]);
    if (updateExit != 0) {
      stderr.writeln(
        'apt-get update exited with $updateExit; continuing and verifying '
        'dependency installation directly.',
      );
    }

    for (final missingPkgs in missingGroups) {
      stdout.writeln(
        'Installing Linux build dependencies: ${missingPkgs.join(', ')}...',
      );
      final installExit = await _installLinuxPackages(missingPkgs);
      if (installExit != 0) return installExit;
    }
  }

  const appimagetool = '/usr/local/bin/appimagetool';
  if (File(appimagetool).existsSync()) {
    stdout.writeln('appimagetool already installed, skipping.');
    return 0;
  }
  stdout.writeln('Downloading appimagetool...');
  final downloadName =
      'appimagetool-${appImageToolArch(_detectArch())}.AppImage';
  final dlResult = await Process.run('wget', [
    '-O',
    appimagetool,
    'https://github.com/AppImage/AppImageKit/releases/download/continuous/$downloadName',
  ]);
  if (dlResult.exitCode != 0) {
    stderr.write(dlResult.stderr);
    return dlResult.exitCode;
  }
  await Process.run('chmod', ['+x', appimagetool]);
  return 0;
}

String appImageToolArch(String arch) {
  return arch == 'arm64' ? 'aarch64' : 'x86_64';
}

/// Ubuntu 24.04 ships libfuse2 under its time64 name, which `dpkg -s libfuse2` cannot see.
const _debianPackageAliases = <String, List<String>>{
  'libfuse2': ['libfuse2t64'],
};

Future<bool> _isDebianPackageInstalled(String pkg) async {
  for (final name in [pkg, ...?_debianPackageAliases[pkg]]) {
    final result = await Process.run('dpkg', ['-s', name]);
    if (result.exitCode == 0 &&
        (result.stdout as String).contains('Status: install ok installed')) {
      return true;
    }
  }
  return false;
}

Future<bool> _areDebianPackagesInstalled(List<String> pkgs) async {
  for (final pkg in pkgs) {
    if (!await _isDebianPackageInstalled(pkg)) {
      return false;
    }
  }
  return true;
}

Future<int> _installLinuxPackages(List<String> pkgs) async {
  final exitCode = await _runLinuxDependencyCommand([
    'apt-get',
    'install',
    '-y',
    ...pkgs,
  ]);
  if (exitCode == 0) return 0;

  if (await _areDebianPackagesInstalled(pkgs)) {
    stderr.writeln(
      'apt-get install exited with $exitCode, but all requested packages are '
      'installed; continuing.',
    );
    return 0;
  }

  return exitCode;
}

Future<int> _runLinuxDependencyCommand(List<String> command) async {
  final sudoCommand = [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'NEEDRESTART_MODE=a',
    ...command,
  ];
  stdout.writeln('exec: sudo ${sudoCommand.join(' ')}');
  final result = await Process.start('sudo', sudoCommand);
  result.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  result.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Linux dependency command failed with exit code $exitCode.');
  }
  return exitCode;
}
