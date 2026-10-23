import 'dart:io';

import 'package:flutter/services.dart';

abstract interface class IpingAuthSession {
  Future<Uri?> authenticate(Uri url, {required String callbackScheme});

  Future<void> cancel();
}

class _MacAuthSession implements IpingAuthSession {
  static const _channel = MethodChannel('iping/auth_session');

  @override
  Future<Uri?> authenticate(Uri url, {required String callbackScheme}) async {
    final result = await _channel.invokeMethod<String>('authenticate', {
      'url': url.toString(),
      'callbackUrlScheme': callbackScheme,
    });
    return result == null ? null : Uri.parse(result);
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

// Other platforms use app links until auth tabs consistently close after login.
IpingAuthSession? ipingSystemAuthSession() =>
    Platform.isMacOS ? _MacAuthSession() : null;
