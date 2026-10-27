import 'package:fl_clash/l10n/l10n.dart';

abstract interface class RouterClient {
  Future<Object?> call(String method, [Map<String, Object?> args = const {}]);
  Future<void> signIn({bool register = false});
  void cancelSignIn();
  void open(String url);
  void exportText(String name, String content);
  Map<String, Object?> readPreferences();
  void writePreferences(Map<String, Object?> value);
}

class RouterException implements Exception {
  const RouterException(this.message);

  final String message;

  @override
  String toString() => routerErrorMessage(message, AppLocalizations.current);
}

String routerErrorMessage(String code, AppLocalizations l) => switch (code) {
  'agent_unavailable' => l.routerAgentUnavailable,
  'service_conflict' => l.routerServiceConflict,
  'busy' => l.routerBusy,
  'invalid_request' => l.invalidSettingTip(l.settings),
  'resource_changed' => l.resourceChangedTip,
  'invalid_proxy' => l.invalidSettingTip(l.proxies),
  'network_error' ||
  'request_failed' ||
  'invalid_response' => l.ipingNetworkError,
  'invalid_subscription' || 'sync_required' => l.ipingSubscriptionError,
  'no_nodes' => l.ipingManualNoNodes,
  'not_logged_in' ||
  'login_required' ||
  'login_expired' => l.ipingSessionExpired,
  'service_failed' ||
  'rollback_failed' ||
  'storage_error' ||
  'interrupted' ||
  'invalid_login' ||
  'already_logged_in' => l.routerOperationFailed,
  _ => code,
};
