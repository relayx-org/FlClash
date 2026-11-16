abstract interface class IpingAuthSession {
  Future<Uri?> authenticate(Uri url, {required String callbackScheme});

  Future<void> cancel();
}

// Prefer the default browser on every platform. ASWebAuthenticationSession
// shares Safari's cookie jar, so a website account switch in Chrome/Firefox
// never reaches the next app login and the previous account is reused.
IpingAuthSession? ipingSystemAuthSession() => null;
