import 'dart:ffi';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'update.dart';

Future<String> ipingUpdateTarget() async {
  if (Platform.isIOS) return 'ios-app-store';
  final arch = ipingUpdateArch(Abi.current());
  final platform = Platform.operatingSystem;
  final format = switch (platform) {
    'android' => 'apk',
    'windows' => 'exe',
    'macos' => 'zip',
    'linux' => await ipingLinuxUpdateFormat(
      executable: Platform.resolvedExecutable,
      appImage: Platform.environment['APPIMAGE'],
    ),
    _ => throw UnsupportedError('Unsupported update platform'),
  };
  return '$platform-$arch-$format';
}

Future<String> ipingLinuxUpdateFormat({
  required String executable,
  String? appImage,
  ProcessRunner run = Process.run,
}) async {
  if (appImage != null) return 'AppImage';
  for (final (format, command, arguments) in [
    ('deb', '/usr/bin/dpkg-query', ['--search', executable]),
    ('rpm', '/usr/bin/rpm', ['-qf', executable]),
  ]) {
    try {
      if ((await run(command, arguments)).exitCode == 0) return format;
    } on ProcessException {
      continue;
    }
  }
  return 'zip';
}

Future<void> _run(String command, List<String> arguments) async {
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      command,
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
}

Future<void> installIpingUpdate(
  File file,
  String format, {
  PasswordPrompt? askPassword,
}) async {
  final executable = Platform.resolvedExecutable;
  if (Platform.isWindows) {
    final directory = p.dirname(executable);
    if (!Windows().runas(
      file.path,
      '/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /UPDATE=1 /DIR="$directory"',
    )) {
      throw StateError('Installer launch cancelled');
    }
    return;
  }
  if (Platform.isLinux && (format == 'deb' || format == 'rpm')) {
    final command = format == 'deb'
        ? ['/usr/bin/apt-get', 'install', '--reinstall', '--yes', file.path]
        : ['/usr/bin/rpm', '-U', '--replacepkgs', file.path];
    final elevation = askPassword == null
        ? linuxElevation
        : LinuxElevation(askPassword: askPassword);
    if (!await elevation.elevate(command)) {
      throw StateError('Package installation cancelled');
    }
    await _afterExit(file.parent, _restartScript, [executable]);
    return;
  }
  if (Platform.isLinux && format == 'AppImage') {
    final target = Platform.environment['APPIMAGE']!;
    final staged = '$target.update-$pid';
    await file.copy(staged);
    await _run('/bin/chmod', ['755', staged]);
    await _afterExit(file.parent, ipingReplacementScript, [
      staged,
      target,
      target,
      'file',
    ]);
    return;
  }
  final extracted = Directory(p.join(file.parent.path, 'extracted'));
  await extracted.create();
  await _run(
    Platform.isMacOS ? '/usr/bin/ditto' : '/usr/bin/unzip',
    Platform.isMacOS
        ? ['-x', '-k', file.path, extracted.path]
        : ['-q', file.path, '-d', extracted.path],
  );
  final String source;
  final String target;
  if (Platform.isMacOS) {
    source = p.join(extracted.path, '$appName.app');
    final suffix = '.app${p.separator}Contents${p.separator}';
    final index = executable.lastIndexOf(suffix);
    if (index < 0 || !await Directory(source).exists()) {
      throw const FormatException('Invalid macOS update bundle');
    }
    target = executable.substring(0, index + 4);
    await _run('/usr/bin/codesign', ['--verify', '--deep', '--strict', source]);
  } else {
    source = extracted.path;
    target = p.dirname(executable);
    if (!await File(p.join(source, appName)).exists()) {
      throw const FormatException('Invalid Linux update bundle');
    }
  }
  final staged = '$target.update-$pid';
  await _run(
    Platform.isMacOS ? '/usr/bin/ditto' : '/bin/cp',
    Platform.isMacOS ? [source, staged] : ['-a', source, staged],
  );
  await _afterExit(file.parent, ipingReplacementScript, [
    staged,
    target,
    Platform.isMacOS ? target : p.join(target, appName),
    Platform.isMacOS ? 'macos' : 'directory',
  ]);
}

Future<void> _afterExit(
  Directory directory,
  String script,
  List<String> arguments,
) async {
  final file = File(p.join(directory.path, 'install.sh'));
  await file.writeAsString(script, flush: true);
  await Process.start('/bin/sh', [
    file.path,
    '$pid',
    ...arguments,
  ], mode: ProcessStartMode.detached);
}

const _waitForExit = r'''
set -eu
parent="$1"
shift
count=0
while kill -0 "$parent" 2>/dev/null; do
  count=$((count + 1))
  [ "$count" -lt 120 ] || exit 1
  sleep 1
done
''';

const _restartScript =
    _waitForExit +
    r'''
exec "$1"
''';

@visibleForTesting
const ipingReplacementScript =
    _waitForExit +
    r'''
staged="$1"
target="$2"
executable="$3"
kind="$4"
backup="$target.previous-$$"
mv "$target" "$backup"
if ! mv "$staged" "$target"; then
  mv "$backup" "$target"
  exit 1
fi
if [ "$kind" = macos ]; then
  if ! /usr/bin/open "$target"; then
    mv "$target" "$staged"
    mv "$backup" "$target"
    /usr/bin/open "$target"
    exit 1
  fi
else
  if [ ! -x "$executable" ]; then
    mv "$target" "$staged"
    mv "$backup" "$target"
    exit 1
  fi
  "$executable" >/dev/null 2>&1 &
fi
rm -rf "$backup"
''';
