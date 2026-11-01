import 'package:share_plus/share_plus.dart';

import 'print.dart';

/// Opens the system share sheet with [text].
///
/// Returns false when the platform has no share sheet to offer, so a caller
/// can tell an unsupported platform apart from a dismissed sheet.
Future<bool> shareText(String text) async {
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    return result.status != ShareResultStatus.unavailable;
  } catch (error) {
    commonPrint.log('Unable to share: ${compactError(error)}');
    return false;
  }
}
