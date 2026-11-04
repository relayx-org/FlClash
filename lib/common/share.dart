import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import 'print.dart';

///
Future<bool> shareImage(
  Uint8List bytes, {
  required String name,
  String? text,
  Rect? origin,
}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
        text: text,
        sharePositionOrigin: origin,
        downloadFallbackEnabled: true,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (error) {
    commonPrint.log('Unable to share the image: ${compactError(error)}');
    return false;
  }
}
