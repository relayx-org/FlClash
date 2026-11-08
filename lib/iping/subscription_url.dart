bool isIpingSubscriptionUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      !RegExp(r'\s').hasMatch(value);
}

// Subscription tokens sit in the path as often as in the query.
String maskIpingSubscriptionUrl(String value) {
  final uri = Uri.parse(value);
  final secret = uri.path.length > 1 || uri.hasQuery || uri.hasFragment;
  return secret ? '${uri.authority}/••••••' : uri.authority;
}
