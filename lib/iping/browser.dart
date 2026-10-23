import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'auth_session.dart';

typedef IpingCodeExchange =
    Future<IpingAccount> Function({
      required String code,
      required String verifier,
    });

class IpingBrowserLogin {
  IpingBrowserLogin({
    required this.exchange,
    this.site = ipingSite,
    this.session,
    Future<bool> Function(Uri)? open,
    this.timeout = const Duration(minutes: 5),
  }) : open =
           open ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final String site;
  final IpingCodeExchange exchange;
  final IpingAuthSession? session;
  final Future<bool> Function(Uri) open;
  final Duration timeout;
  Completer<Uri?>? _callback;
  String? _state;

  static final _base64Url256 = RegExp(r'^[A-Za-z0-9_-]{43}$');

  String _random() {
    final random = Random.secure();
    return base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  static String codeChallenge(String verifier) => base64UrlEncode(
    sha256.convert(ascii.encode(verifier)).bytes,
  ).replaceAll('=', '');

  bool handleCallback(Uri uri) {
    final callback = _callback;
    final parameters = uri.queryParametersAll;
    if (callback == null ||
        callback.isCompleted ||
        uri.scheme != 'iping' ||
        uri.host != 'auth' ||
        uri.path != '/callback' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty ||
        parameters.length != 2 ||
        parameters['state']?.length != 1 ||
        uri.queryParameters['state'] != _state ||
        parameters['code']?.length != 1 ||
        !_base64Url256.hasMatch(uri.queryParameters['code']!)) {
      return false;
    }
    callback.complete(uri);
    return true;
  }

  void _launch(Uri url, Completer<Uri?> callback) {
    void settle(Uri? uri) {
      if (uri == null || !handleCallback(uri)) {
        if (!callback.isCompleted) callback.complete(null);
      }
    }

    Future<void> fallback() async {
      try {
        if (!await open(url) && !callback.isCompleted) {
          callback.completeError(
            const IpingException(IpingFailure.unavailable),
          );
        }
      } catch (_) {
        if (!callback.isCompleted) {
          callback.completeError(
            const IpingException(IpingFailure.unavailable),
          );
        }
      }
    }

    final session = this.session;
    if (session == null) {
      unawaited(fallback());
      return;
    }
    // If the system sheet cannot start, the app-link callback path still works.
    unawaited(
      session
          .authenticate(url, callbackScheme: 'iping')
          .then(settle, onError: (Object _) => fallback()),
    );
  }

  Future<IpingAccount?> signIn({bool register = false}) async {
    if (_callback != null) return null;
    _state = _random();
    final verifier = _random();
    final callback = Completer<Uri?>();
    _callback = callback;
    // Install the timeout before handing control to another application.
    final response = callback.future.timeout(timeout, onTimeout: () => null);
    try {
      final returnTo = Uri(
        path: '/client-login',
        queryParameters: {
          'state': _state!,
          'code_challenge': codeChallenge(verifier),
          'code_challenge_method': 'S256',
        },
      );
      final url = register
          ? Uri.parse('$site/handler/sign-up').replace(
              queryParameters: {'after_auth_return_to': returnTo.toString()},
            )
          : Uri.parse(site).resolveUri(returnTo);
      _launch(url, callback);
      final uri = await response;
      if (uri == null) return null;
      return await exchange(
        code: uri.queryParameters['code']!,
        verifier: verifier,
      );
    } finally {
      if (!callback.isCompleted) {
        callback.complete(null);
        _cancelSession();
      }
      if (identical(_callback, callback)) {
        _callback = null;
        _state = null;
      }
    }
  }

  void _cancelSession() {
    unawaited(session?.cancel().catchError((Object _) {}));
  }

  void cancel() {
    final callback = _callback;
    if (callback != null && !callback.isCompleted) {
      callback.complete(null);
      _cancelSession();
    }
    _callback = null;
    _state = null;
  }
}
