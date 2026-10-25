import 'dart:convert';
import 'dart:js_interop';

import 'client.dart';

@JS('ipingRequest')
external JSPromise<JSString> _request(JSString method, JSString args);

@JS('ipingAuthorize')
external JSPromise<JSBoolean> _authorize(JSString key);

@JS('ipingSignIn')
external JSPromise<JSAny?> _signIn(JSBoolean register);

@JS('ipingCancelSignIn')
external void _cancelSignIn();

@JS('ipingOpen')
external void _open(JSString url);

@JS('ipingDownload')
external void _download(JSString name, JSString content);

@JS('ipingReadPreferences')
external JSString _readPreferences();
@JS('ipingWritePreferences')
external void _writePreferences(JSString value);

class WebRouterClient implements RouterClient {
  const WebRouterClient();

  @override
  Future<bool> authorize([String? key]) async {
    try {
      return (await _authorize((key ?? '').toJS).toDart).toDart;
    } catch (error) {
      throw RouterException(_errorCode(error));
    }
  }

  @override
  Map<String, Object?> readPreferences() {
    try {
      final value = jsonDecode(_readPreferences().toDart);
      return value is Map ? Map<String, Object?>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  @override
  void writePreferences(Map<String, Object?> value) =>
      _writePreferences(jsonEncode(value).toJS);

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      final result = await _request(method.toJS, jsonEncode(args).toJS).toDart;
      return jsonDecode(result.toDart);
    } catch (error) {
      throw RouterException(_errorCode(error));
    }
  }

  @override
  Future<void> signIn({bool register = false}) async {
    try {
      await _signIn(register.toJS).toDart;
    } catch (error) {
      throw RouterException(_errorCode(error));
    }
  }

  @override
  void cancelSignIn() => _cancelSignIn();

  @override
  void open(String url) => _open(url.toJS);

  @override
  void exportText(String name, String content) =>
      _download(name.toJS, content.toJS);
}

String _errorCode(Object error) {
  final text = error.toString();
  if (text.startsWith('TypeError:') || text.startsWith('AbortError:')) {
    return 'agent_unavailable';
  }
  return text.replaceFirst(RegExp(r'^Error:\s*'), '');
}
