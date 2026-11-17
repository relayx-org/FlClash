import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

const _geoFiles = ['GEOIP.metadb', 'GEOIP.dat', 'GEOSITE.dat', 'ASN.mmdb'];

Future<void> installBundledGeodata(String home, {AssetBundle? bundle}) async {
  bundle ??= rootBundle;
  Map<String, dynamic>? files;
  try {
    final manifest =
        jsonDecode(await bundle.loadString('assets/data/manifest.json'))
            as Map<String, dynamic>;
    files = manifest['files'] as Map<String, dynamic>;
  } on FlutterError {
    // Development builds can use the checked-in assets without a release snapshot.
  }
  for (final name in _geoFiles) {
    final metadata = files?[name] as Map<String, dynamic>?;
    final digest = metadata?['sha256'] as String?;
    final size = metadata?['size'] as int?;
    if (files != null &&
        (digest == null ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
            size == null ||
            size <= 0)) {
      throw FormatException('Invalid bundled geodata: $name');
    }
    final target = File(p.join(home, name));
    final marker = File('${target.path}.bundled.sha256');
    if (await target.exists()) {
      if (files == null ||
          (await marker.exists() && await marker.readAsString() == digest)) {
        continue;
      }
    }
    final data = await bundle.load('assets/data/$name');
    await compute(_installGeoFile, (
      path: target.path,
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      digest: digest,
      size: size,
    ));
  }
}

void _installGeoFile(
  ({String path, Uint8List bytes, String? digest, int? size}) input,
) {
  if (input.digest != null &&
      (input.bytes.length != input.size ||
          sha256.convert(input.bytes).toString() != input.digest)) {
    throw const FormatException('Bundled geodata failed verification');
  }
  final staging = Directory(p.dirname(input.path)).createTempSync('.geodata-');
  try {
    final staged = File(p.join(staging.path, 'data'));
    staged.writeAsBytesSync(input.bytes, flush: true);
    staged.renameSync(input.path);
    if (input.digest != null) {
      final marker = File(p.join(staging.path, 'marker'));
      marker.writeAsStringSync(input.digest!, flush: true);
      marker.renameSync('${input.path}.bundled.sha256');
    }
  } finally {
    staging.deleteSync(recursive: true);
  }
}
