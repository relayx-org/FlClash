import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/iping/api.dart';

import 'client.dart';

const _proxyKey = '00000000-0000-0000-0000-000000000000';

IpingApi createRouterIpingClient(RouterClient client, String Function() site) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
    ),
  )..httpClientAdapter = _RouterApiAdapter(client);
  return IpingApi(
    dio: dio,
    site: site(),
    siteResolver: site,
    apiKey: () => _proxyKey,
  );
}

class _RouterApiAdapter implements HttpClientAdapter {
  _RouterApiAdapter(this.client);

  final RouterClient client;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = await client.call('api_call', {
      'method': options.method,
      'path': options.uri.path.replaceFirst(RegExp(r'^/api/'), ''),
      'params': options.uri.queryParameters,
      if (options.data != null) 'body': options.data,
    });
    if (result is! Map) {
      throw DioException(requestOptions: options, message: 'invalid_response');
    }
    final body = result['body'];
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      (result['status'] as num?)?.toInt() ?? 500,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
