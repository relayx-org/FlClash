import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test(
      'names cross-built macOS packages for their selected architecture',
      () {
        const pubspec = '''
hooks:
  user_defines:
    setup:
      macos_architecture: amd64
''';

        expect(setup.packageArchitecture('macos', pubspec, 'arm64'), 'amd64');
        expect(setup.packageArchitecture('macos', 'name: x', 'arm64'), 'arm64');
        expect(setup.packageArchitecture('linux', pubspec, 'arm64'), 'arm64');
      },
    );

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('refuses to package while a native build hook is skipped', () {
      const pubspec = '''
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: true
''';

      expect(setup.packagesNotBuildingAssets(pubspec), ['setup']);
      expect(setup.packagesNotBuildingAssets('name: x\n'), isEmpty);
    });

    test('packages every Linux format on every architecture', () {
      expect(setup.createPackageTargets('linux', null), 'deb,appimage,rpm,zip');
      expect(setup.createPackageTargets('linux', 'deb'), 'deb');
      expect(setup.createPackageTargets('ios', null), 'ipa');
      expect(
        () => setup.createPackageTargets('ios', 'zip'),
        throwsArgumentError,
      );
      expect(setup.createPackageTargets('macos', null), 'dmg,zip');
    });

    test('iOS packages arm64 devices on either macOS host architecture', () {
      expect(setup.canBuildPlatform('ios', 'macos'), isTrue);
      expect(setup.canBuildPlatform('ios', 'linux'), isFalse);
      expect(setup.canBuildPlatform('ios', 'windows'), isFalse);
      expect(setup.packageArchitecture('ios', 'name: x', 'amd64'), 'arm64');
      expect(setup.packageArchitecture('ios', 'name: x', 'arm64'), 'arm64');
    });

    test('downloads the appimagetool build matching the host', () {
      expect(setup.appImageToolArch('arm64'), 'aarch64');
      expect(setup.appImageToolArch('amd64'), 'x86_64');
    });
  });
}
