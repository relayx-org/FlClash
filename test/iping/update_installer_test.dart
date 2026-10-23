import 'dart:io';

import 'package:fl_clash/iping/update_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'keeps a portable installation portable on a package-based distro',
    () async {
      final commands = <String>[];
      expect(
        await ipingLinuxUpdateFormat(
          executable: '/home/user/iPing/iPing',
          run: (command, arguments) async {
            commands.add(command);
            return ProcessResult(1, 1, '', 'not owned by a package');
          },
        ),
        'zip',
      );
      expect(commands, ['/usr/bin/dpkg-query', '/usr/bin/rpm']);
    },
  );

  test('uses the manager that owns the running executable', () async {
    expect(
      await ipingLinuxUpdateFormat(
        executable: '/opt/iPing/iPing',
        run: (command, arguments) async {
          if (command.endsWith('dpkg-query')) {
            throw ProcessException(command, arguments);
          }
          expect(arguments, ['-qf', '/opt/iPing/iPing']);
          return ProcessResult(1, 0, 'iping', '');
        },
      ),
      'rpm',
    );
    expect(
      await ipingLinuxUpdateFormat(
        executable: '/tmp/.mount_iPing/iPing',
        appImage: '/home/user/iPing.AppImage',
        run: (_, _) async => throw StateError('must not query packages'),
      ),
      'AppImage',
    );
  });

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iping update \$ ');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<ProcessResult> replace(String staged, String target) async {
    final script = File(p.join(directory.path, 'install.sh'));
    await script.writeAsString(ipingReplacementScript);
    return Process.run('/bin/sh', [
      script.path,
      '2147483647',
      staged,
      target,
      p.join(target, 'iPing'),
      'directory',
    ]);
  }

  test('replaces a bundle and launches the new executable', () async {
    final target = await Directory(p.join(directory.path, 'old app')).create();
    await File(p.join(target.path, 'version')).writeAsString('old');
    final staged = await Directory(p.join(directory.path, 'new app')).create();
    await File(p.join(staged.path, 'version')).writeAsString('new');
    final executable = File(p.join(staged.path, 'iPing'));
    await executable.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('/bin/chmod', ['755', executable.path]);

    final result = await replace(staged.path, target.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(await File(p.join(target.path, 'version')).readAsString(), 'new');
    expect(await staged.exists(), isFalse);
    expect(
      directory.listSync().where((entry) => entry.path.contains('.previous-')),
      isEmpty,
    );
  }, skip: Platform.isWindows);

  test('restores the previous bundle when staging is missing', () async {
    final target = await Directory(p.join(directory.path, 'old app')).create();
    await File(p.join(target.path, 'version')).writeAsString('old');

    final result = await replace(
      p.join(directory.path, 'missing update'),
      target.path,
    );

    expect(result.exitCode, isNot(0));
    expect(await File(p.join(target.path, 'version')).readAsString(), 'old');
  }, skip: Platform.isWindows);

  test(
    'restores the previous bundle if the new executable is absent',
    () async {
      final target = await Directory(
        p.join(directory.path, 'old app'),
      ).create();
      await File(p.join(target.path, 'version')).writeAsString('old');
      final staged = await Directory(
        p.join(directory.path, 'new app'),
      ).create();

      final result = await replace(staged.path, target.path);

      expect(result.exitCode, isNot(0));
      expect(await File(p.join(target.path, 'version')).readAsString(), 'old');
      expect(await staged.exists(), isTrue);
    },
    skip: Platform.isWindows,
  );
}
