import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/update_manifest.dart';

void main() {
  test(
    'Linux Agent downloads and bootstrap share the published update manifest',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'iping-router-update-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final artifacts = await Directory('${directory.path}/artifacts').create();
      final output = Directory('${directory.path}/output');
      for (final name in [
        'iPing-1.2.3-macos-arm64.zip',
        'iPing-1.2.3-linux-agent-mipsel.zip',
        'iPing-1.2.3-linux-agent-aarch64.zip',
        'install-linux.sh',
      ]) {
        await File('${artifacts.path}/$name').writeAsBytes([1, 2, 3]);
      }
      final manifest = await buildUpdateManifest(
        artifacts: artifacts,
        output: output,
        version: '1.2.3',
        buildNumber: 42,
        baseUrl: Uri.parse('https://video.iping.my/releases/'),
        requireComplete: false,
      );
      final downloads = manifest['downloads']! as Map;
      expect(
        downloads.keys,
        containsAll([
          'linux-agent-mipsel',
          'linux-agent-aarch64',
          'linux-agent-installer',
        ]),
      );
      final router = downloads['linux-agent-mipsel'] as Map;
      expect(
        router['url'],
        'https://video.iping.my/releases/1.2.3+42/iPing-1.2.3-linux-agent-mipsel.zip',
      );
      expect(router['sha256'], hasLength(64));
      expect(router['size'], 3);
      expect((manifest['assets']! as Map).keys, ['macos-arm64-zip']);
      expect(await File('${output.path}/install-linux.sh').readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(
        await File('${output.path}/1.2.3+42/install-linux.sh').readAsBytes(),
        [1, 2, 3],
      );
      expect(
        downloadArtifactTarget('iPing-1.2.3-ios-arm64.zip', '1.2.3'),
        isNull,
      );
      expect(
        downloadArtifactTarget('iPing-1.2.3-linux-agent-x86_64.ipa', '1.2.3'),
        isNull,
      );
    },
  );

  test(
    'accepts the supported desktop matrix without Windows or Linux ARM64',
    () async {
      final directory = await Directory.systemTemp.createTemp('iping-matrix-');
      addTearDown(() => directory.delete(recursive: true));
      final input = await Directory('${directory.path}/dist').create();
      const names = [
        'android-armeabi-v7a.apk',
        'android-arm64-v8a.apk',
        'android-x86_64.apk',
        'windows-amd64-setup.exe',
        'macos-amd64.zip',
        'macos-arm64.zip',
        'linux-amd64.zip',
        'linux-amd64.deb',
        'linux-amd64.rpm',
        'linux-amd64.AppImage',
        'ios-arm64.ipa',
        'linux-agent-x86_64.zip',
        'linux-agent-aarch64.zip',
        'linux-agent-armv7.zip',
        'linux-agent-mips.zip',
        'linux-agent-mipsel.zip',
      ];
      for (final name in names) {
        await File('${input.path}/iPing-1.0.0-$name').writeAsBytes([1]);
      }
      await File('${input.path}/install-linux.sh').writeAsBytes([1]);
      final manifest = await buildUpdateManifest(
        artifacts: input,
        output: Directory('${directory.path}/output'),
        version: '1.0.0',
        buildNumber: 1,
        baseUrl: Uri.parse('https://example.com/releases/'),
      );
      expect(manifest['assets'], hasLength(10));
    },
  );

  test(
    'iOS and Linux Agent downloads are staged alongside the app update packages',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'iping-extra-release-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final input = await Directory('${directory.path}/dist').create();
      const names = [
        'iPing-1.0.0-macos-arm64.zip',
        'iPing-1.0.0-ios-arm64.ipa',
        'iPing-1.0.0-linux-agent-x86_64.zip',
        'iPing-1.0.0-linux-agent-aarch64.zip',
      ];
      for (final name in names) {
        await File('${input.path}/$name').writeAsBytes([1, 2]);
      }
      await File('${input.path}/iPing-0.9.0-ios-arm64.ipa').writeAsBytes([9]);
      final output = Directory('${directory.path}/output');
      final manifest = await buildUpdateManifest(
        artifacts: input,
        output: output,
        version: '1.0.0',
        buildNumber: 42,
        baseUrl: Uri.parse('https://example.com/releases/'),
        requireComplete: false,
      );
      expect((manifest['assets'] as Map).keys, ['macos-arm64-zip']);
      for (final name in names) {
        expect(await File('${output.path}/1.0.0+42/$name').readAsBytes(), [
          1,
          2,
        ]);
      }
      expect(
        await File(
          '${output.path}/1.0.0+42/iPing-0.9.0-ios-arm64.ipa',
        ).exists(),
        isFalse,
      );
    },
  );

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
