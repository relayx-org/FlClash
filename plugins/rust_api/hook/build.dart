import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

// Android needs the NDK's libclang; iOS needs Xcode's libclang and SDK headers.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets) {
    return const {};
  }
  final code = input.config.code;
  if (code.targetOS != OS.android && code.targetOS != OS.iOS) return const {};
  final environment = <String, String>{};
  if (code.targetOS == OS.iOS) {
    final sdk = code.iOS.targetSdk.type;
    final result = Process.runSync('xcrun', ['--sdk', sdk, '--show-sdk-path']);
    if (result.exitCode != 0) throw StateError('Cannot locate the $sdk SDK');
    environment['BINDGEN_EXTRA_CLANG_ARGS'] =
        '-isysroot ${result.stdout.toString().trim()}';
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64']) {
    final directory = Directory(
      '${llvmRoot.path}${Platform.pathSeparator}$name',
    );
    if (directory.existsSync() && directory.listSync().any(_isLibclang)) {
      return {...environment, 'LIBCLANG_PATH': directory.path};
    }
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib or lib64); the compiler Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}
