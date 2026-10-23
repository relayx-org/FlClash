import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/update_manifest.dart';

void main() {
  test('maps platform package filenames to runtime targets', () {
    expect(
      updateArtifactTarget('iPing-1.0.0-android-arm64-v8a.apk', '1.0.0'),
      'android-arm64-apk',
    );
    expect(
      updateArtifactTarget('iPing-1.0.0-linux-arm64.AppImage', '1.0.0'),
      'linux-arm64-AppImage',
    );
    for (final arch in ['amd64', 'arm64']) {
      expect(
        updateArtifactTarget('iPing-1.0.0-windows-$arch-setup.exe', '1.0.0'),
        'windows-$arch-exe',
      );
    }
    expect(
      updateArtifactTarget('iPing-1.0.1-macos-amd64.zip', '1.0.0'),
      isNull,
    );
  });

  test(
    'publishes immutable version paths and refuses incomplete releases',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'iping-manifest-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = await Directory('${directory.path}/dist').create();
      await File(
        '${input.path}/iPing-1.0.0-macos-arm64.zip',
      ).writeAsBytes([1, 2, 3]);
      final output = Directory('${directory.path}/output');
      final args = (
        artifacts: input,
        output: output,
        version: '1.0.0',
        buildNumber: 10,
        baseUrl: Uri.parse('https://example.com/releases/'),
      );
      await expectLater(
        buildUpdateManifest(
          artifacts: args.artifacts,
          output: args.output,
          version: args.version,
          buildNumber: args.buildNumber,
          baseUrl: args.baseUrl,
        ),
        throwsStateError,
      );
      expect(await File('${output.path}/latest.json').exists(), isFalse);
      final manifest = await buildUpdateManifest(
        artifacts: input,
        output: output,
        version: args.version,
        buildNumber: args.buildNumber,
        baseUrl: args.baseUrl,
        requireComplete: false,
      );
      final asset = (manifest['assets'] as Map)['macos-arm64-zip'] as Map;
      expect(
        asset['url'],
        'https://example.com/releases/1.0.0+10/iPing-1.0.0-macos-arm64.zip',
      );
      expect(asset['sha256'], hasLength(64));
      expect(asset['size'], 3);
      expect(
        await File(
          '${output.path}/1.0.0+10/iPing-1.0.0-macos-arm64.zip',
        ).readAsBytes(),
        [1, 2, 3],
      );
    },
  );
}
