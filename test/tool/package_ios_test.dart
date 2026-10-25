import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/package_ios.dart';

void main() {
  test('explicit iOS signing happens during Xcode archive export', () {
    final arguments = createIosBuildArguments(
      flutterBuildArgs: ['dart-define-from-file=env.json'],
      exportOptionsPlist: '/tmp/signing options.plist',
    );
    expect(arguments.take(3), ['build', 'ipa', '--release']);
    expect(arguments, contains('--no-codesign'));
    expect(arguments, contains('--dart-define-from-file=env.json'));
    expect(
      arguments.any((value) => value.startsWith('--export-method')),
      isFalse,
    );
    expect(
      createIosBuildArguments(flutterBuildArgs: []),
      contains('--export-method=app-store'),
    );
    final export = createIosExportArguments(
      rootDir: '/tmp/project',
      exportOptionsPlist: '/tmp/signing options.plist',
    );
    expect(export.take(2), ['xcodebuild', '-exportArchive']);
    expect(export, contains('/tmp/project/build/ios/archive/Runner.xcarchive'));
    expect(export, contains('/tmp/project/build/ios/ipa'));
    expect(export.last, '/tmp/signing options.plist');
    expect(export, isNot(contains('-allowProvisioningUpdates')));
  });

  for (final files in [
    <String, List<int>>{},
    {'app.ipa': <int>[]},
    {
      'a.ipa': [1],
      'b.ipa': [2],
    },
  ]) {
    test(
      'failed or ambiguous export preserves the previous IPA: ${files.keys}',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'iping-ipa-invalid-',
        );
        addTearDown(() => root.delete(recursive: true));
        final exports = await Directory(p.join(root.path, 'exports')).create();
        for (final entry in files.entries) {
          await File(p.join(exports.path, entry.key)).writeAsBytes(entry.value);
        }
        final output = File(p.join(root.path, 'previous.ipa'));
        await output.writeAsBytes([7]);
        await expectLater(
          packageSignedIosIpa(exports: exports, output: output),
          throwsStateError,
        );
        expect(await output.readAsBytes(), [7]);
      },
    );
  }

  test('an unsigned application cannot replace the release IPA', () async {
    final root = await Directory.systemTemp.createTemp('iping-ipa-unsigned-');
    addTearDown(() => root.delete(recursive: true));
    final payload = Directory(p.join(root.path, 'Payload'));
    final info = File(p.join(payload.path, 'Runner.app', 'Info.plist'));
    await info.parent.create(recursive: true);
    await info.writeAsString('unsigned');
    final exports = await Directory(p.join(root.path, 'exports')).create();
    final result = await Process.run('/usr/bin/ditto', [
      '-c',
      '-k',
      '--keepParent',
      payload.path,
      p.join(exports.path, 'app.ipa'),
    ]);
    expect(result.exitCode, 0);
    final output = File(p.join(root.path, 'previous.ipa'));
    await output.writeAsBytes([7]);
    await expectLater(
      packageSignedIosIpa(exports: exports, output: output),
      throwsStateError,
    );
    expect(await output.readAsBytes(), [7]);
  }, skip: !Platform.isMacOS);
}
