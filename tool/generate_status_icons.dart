import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'src/icons/ico.dart';

const pngOutputDir = 'assets/images/tray/unix';
const icoOutputDir = 'assets/images/tray/windows';
const macosOutputDir = 'assets/images/tray/macos';
const trayBaseSize = 18;
const trayScales = [1, 2, 3, 4];
const appIconSource = 'assets/images/icon.png';
const windowsAppIconOutput = 'windows/runner/resources/app_icon.ico';
const linuxAppIconOutput = 'assets/images/linux/app_icon.png';
const linuxAppIconSize = 512;
const macosAppIconDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const macosAppIconSizes = [16, 32, 64, 128, 256, 512, 1024];
const iosAppIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const iosLaunchImageDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';

/// Apple's icon grid keeps the 824pt body centred on a 1024pt canvas.
const macosAppIconMargin = 256 * 100 / 1024;
const appIconCornerExponent = 5;
const trayVariants = {
  'status_1': AppIconVariant(grayscale: true),
  'status_2': AppIconVariant(),
  'status_3': AppIconVariant(badge: '#3083C6'),
  'status_4': AppIconVariant(badge: '#EA580C'),
};

final class AppIconVariant {
  const AppIconVariant({this.grayscale = false, this.badge, this.margin = 0});

  final bool grayscale;
  final String? badge;
  final double margin;
}

Future<void> main() async {
  final rsvgConvert = await _findExecutable('rsvg-convert');
  if (rsvgConvert == null) {
    stderr.writeln(
      'rsvg-convert is required. Install librsvg before generating icons.',
    );
    exitCode = 1;
    return;
  }

  await Directory(icoOutputDir).create(recursive: true);
  final tempDir = await Directory.systemTemp.createTemp('status_icons_');
  final renderer = _Renderer(rsvgConvert, tempDir);
  try {
    final raster = File(appIconSource);
    for (final MapEntry(key: name, value: variant) in trayVariants.entries) {
      final source = await renderer.appIcon(raster, variant);
      await _writeTrayVariants(renderer, source, name, pngOutputDir);
      await _writeTrayVariants(renderer, source, name, macosOutputDir);
      await _writeIco(
        renderer,
        source,
        File('$icoOutputDir/$name.ico'),
        sizes: trayIcoSizes,
      );
    }
    final appIcon = await renderer.appIcon(raster, const AppIconVariant());
    await _writeIco(renderer, appIcon, File(windowsAppIconOutput));
    await _writePng(
      renderer,
      appIcon,
      File(linuxAppIconOutput),
      linuxAppIconSize,
    );
    final macosAppIcon = await renderer.appIcon(
      raster,
      const AppIconVariant(margin: macosAppIconMargin),
    );
    for (final size in macosAppIconSizes) {
      await _writePng(
        renderer,
        macosAppIcon,
        File('$macosAppIconDir/app_icon_$size.png'),
        size,
      );
    }
    final iosIcon = File('${tempDir.path}/ios-app-icon.svg');
    await iosIcon.writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024">'
      '<rect width="1024" height="1024" fill="white"/>'
      '<image xlink:href="${raster.uri.pathSegments.last}" width="1024" height="1024"/>'
      '</svg>',
    );
    await _writePng(
      renderer,
      iosIcon,
      File('$iosAppIconDir/AppIcon.png'),
      1024,
    );
    for (final scale in const [1, 2, 3]) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await _writePng(
        renderer,
        appIcon,
        File('$iosLaunchImageDir/LaunchImage$suffix.png'),
        168 * scale,
      );
    }
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _writeTrayVariants(
  _Renderer renderer,
  File source,
  String name,
  String outputDir,
) async {
  for (final scale in trayScales) {
    final directory = scale == 1 ? outputDir : '$outputDir/$scale.0x';
    await _writePng(
      renderer,
      source,
      File('$directory/$name.png'),
      trayBaseSize * scale,
    );
  }
}

Future<void> _writePng(
  _Renderer renderer,
  File source,
  File output,
  int size,
) async {
  await output.parent.create(recursive: true);
  await output.writeAsBytes(await renderer.render(source, size));
  stdout.writeln('Generated ${output.path}');
}

Future<void> _writeIco(
  _Renderer renderer,
  File source,
  File output, {
  List<int> sizes = icoSizes,
}) async {
  final entries = [
    for (final size in sizes)
      IcoEntry(size: size, png: await renderer.render(source, size)),
  ];
  await output.parent.create(recursive: true);
  await output.writeAsBytes(buildIco(entries));
  stdout.writeln('Generated ${output.path}');
}

Future<String?> _findExecutable(String executable) async {
  final result = await Process.run('which', [executable]);
  if (result.exitCode != 0) {
    return null;
  }
  return (result.stdout as String).trim();
}

class _Renderer {
  _Renderer(this.rsvgConvert, this.tempDir);

  final String rsvgConvert;
  final Directory tempDir;
  int _sequence = 0;

  Future<Uint8List> render(File source, int size) async {
    final output = File('${tempDir.path}/${_sequence++}-$size.png');
    final result = await Process.run(rsvgConvert, [
      '-w',
      '$size',
      '-h',
      '$size',
      '-o',
      output.path,
      source.path,
    ]);
    if (result.exitCode != 0) {
      stderr
        ..writeln('Failed to render ${source.path} at ${size}px')
        ..writeln(result.stderr);
      exit(result.exitCode);
    }
    return output.readAsBytes();
  }

  // librsvg only follows image references inside the SVG's own directory, so
  // the raster is copied next to its wrapper before rendering.
  Future<File> appIcon(File raster, AppIconVariant variant) async {
    final copy = await raster.copy('${tempDir.path}/${_basename(raster)}');
    final wrapper = File('${tempDir.path}/app-icon-${_sequence++}.svg');
    final badge = variant.badge;
    final margin = variant.margin;
    final body = 256 - 2 * margin;
    await wrapper.writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" '
      'width="256" height="256" viewBox="0 0 256 256">'
      '<defs>'
      '<clipPath id="shape"><path d="${_superellipse(margin, body)}"/>'
      '</clipPath>'
      '<filter id="mono"><feColorMatrix type="saturate" values="0"/></filter>'
      '</defs>'
      '<image xlink:href="${_basename(copy)}" x="$margin" y="$margin" '
      'width="$body" height="$body" clip-path="url(#shape)"'
      '${variant.grayscale ? ' filter="url(#mono)"' : ''}/>'
      '${badge == null ? '' : '<circle cx="200" cy="200" r="46" '
                'fill="$badge" stroke="#FFFFFF" stroke-width="14"/>'}'
      '</svg>',
    );
    return wrapper;
  }

  String _superellipse(double offset, double size, {int points = 256}) {
    final half = size / 2;
    final centre = offset + half;
    final path = StringBuffer();
    for (var i = 0; i < points; i++) {
      final angle = 2 * math.pi * i / points;
      final x = centre + half * _signedPow(math.cos(angle));
      final y = centre + half * _signedPow(math.sin(angle));
      path.write(
        '${i == 0 ? 'M' : 'L'}${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)}',
      );
    }
    return '${path}Z';
  }

  double _signedPow(double value) =>
      value.sign * math.pow(value.abs(), 2 / appIconCornerExponent);

  String _basename(File file) => file.uri.pathSegments.last;
}
