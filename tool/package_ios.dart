import 'dart:io';

import 'package:path/path.dart' as p;

List<String> createIosBuildArguments({
  required List<String> flutterBuildArgs,
  String? exportOptionsPlist,
}) => [
  'build',
  'ipa',
  '--release',
  if (exportOptionsPlist != null && exportOptionsPlist.isNotEmpty)
    '--no-codesign'
  else
    '--export-method=app-store',
  for (final arg in flutterBuildArgs) '--$arg',
];

List<String> createIosExportArguments({
  required String rootDir,
  required String exportOptionsPlist,
}) => [
  'xcodebuild',
  '-exportArchive',
  '-archivePath',
  p.join(rootDir, 'build', 'ios', 'archive', 'Runner.xcarchive'),
  '-exportPath',
  p.join(rootDir, 'build', 'ios', 'ipa'),
  '-exportOptionsPlist',
  exportOptionsPlist,
];

Future<void> exportSignedIosArchive({
  required String rootDir,
  required String exportOptionsPlist,
}) async {
  final signingDirectory = Platform.environment['IOS_SIGNING_DIR'];
  if (signingDirectory != null && signingDirectory.isNotEmpty) {
    await _run('python3', [
      p.join(rootDir, 'tool', 'ci', 'ios_signing.py'),
      'activate',
      signingDirectory,
    ]);
  }
  await _run(
    '/usr/bin/xcrun',
    createIosExportArguments(
      rootDir: rootDir,
      exportOptionsPlist: exportOptionsPlist,
    ),
  );
}

Future<void> packageSignedIosIpa({
  required Directory exports,
  required File output,
}) async {
  final archives = await exports.exists()
      ? await exports
            .list()
            .where(
              (entry) => entry is File && p.extension(entry.path) == '.ipa',
            )
            .cast<File>()
            .toList()
      : <File>[];
  if (archives.length != 1 || await archives.single.length() == 0) {
    throw StateError('Expected exactly one newly exported, nonempty iOS IPA');
  }
  final staging = await Directory.systemTemp.createTemp('iping-ipa-');
  try {
    await _run('/usr/bin/ditto', [
      '-x',
      '-k',
      archives.single.path,
      staging.path,
    ]);
    final app = p.join(staging.path, 'Payload', 'Runner.app');
    for (final bundle in [app, p.join(app, 'PlugIns', 'PacketTunnel.appex')]) {
      for (final required in ['Info.plist', 'embedded.mobileprovision']) {
        if (!await File(p.join(bundle, required)).exists()) {
          throw StateError('Incomplete signed iOS bundle: $bundle/$required');
        }
      }
      await _run('/usr/bin/codesign', [
        '--verify',
        '--deep',
        '--strict',
        bundle,
      ]);
      final binary = p.basenameWithoutExtension(bundle);
      await _run('/usr/bin/xcrun', [
        'lipo',
        '-verify_arch',
        'arm64',
        p.join(bundle, binary),
      ]);
    }
    await output.parent.create(recursive: true);
    await archives.single.copy(output.path);
    stdout.writeln('Created signed IPA: ${output.path}');
  } finally {
    await staging.delete(recursive: true);
  }
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}
