import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

import 'site_config.dart';
import 'account_statistics.dart';
import 'user_info.dart';

const ipingSite = String.fromEnvironment(
  'IPING_SITE',
  defaultValue: 'https://iping.my',
);

enum IpingFailure { session, unavailable, subscription, storage }

class IpingException implements Exception {
  const IpingException(this.failure);
  final IpingFailure failure;
}

class IpingAccount {
  const IpingAccount({
    required this.id,
    required this.email,
    required this.subscriptionToken,
    this.apiKey,
  });
  final int id;
  final String email;
  final String subscriptionToken;
  final String? apiKey;

  static bool isValidApiKey(String key) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(key);

  Map<String, Object> toJson() => {
    'id': id,
    'email': email,
    'subscription_token': subscriptionToken,
    'api_key': ?apiKey,
  };

  factory IpingAccount.fromJson(Map<String, dynamic> json) {
    final token = json['subscription_token'] as String;
    if (token.isEmpty) {
      throw const FormatException('Missing subscription credential');
    }
    final apiKey = json['api_key'] as String?;
    if (apiKey != null && !isValidApiKey(apiKey)) {
      throw const FormatException('Invalid API credential');
    }
    return IpingAccount(
      id: json['id'] as int,
      email: json['email'] as String,
      subscriptionToken: token,
      apiKey: apiKey,
    );
  }
}

typedef IpingSubscription = ({Uint8List bytes, int nodes});

int ipingNodeCount(String content) {
  try {
    final config = loadYaml(content);
    if (config is! Map || config['proxies'] is! List) {
      throw const IpingException(IpingFailure.subscription);
    }
    final proxies = config['proxies'] as List;
    if (proxies.any(
      (dynamic node) =>
          node is! Map || node['name'] is! String || node['type'] is! String,
    )) {
      throw const IpingException(IpingFailure.subscription);
    }
    return proxies.length;
  } on YamlException {
    throw const IpingException(IpingFailure.subscription);
  }
}

class _SecureHttpOverrides extends HttpOverrides {
  HttpClient createClient() =>
      super.createHttpClient(SecurityContext.defaultContext);
}

class IpingApi {
  IpingApi({Dio? dio, this.site = ipingSite, String? Function()? apiKey})
    : _apiKey = apiKey,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              followRedirects: false,
            ),
          ) {
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => _SecureHttpOverrides().createClient(),
      );
    }
  }
  final Dio _dio;
  final String? Function()? _apiKey;
  final String site;

  IpingApi withApiKey(String? Function() apiKey) =>
      IpingApi(dio: _dio, site: site, apiKey: apiKey);

  Future<T> _request<T>(
    Future<T> Function() operation, {
    Set<int> sessionStatusCodes = const {400, 401, 403, 404, 410},
  }) async {
    try {
      return await operation();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (sessionStatusCodes.contains(status)) {
        throw const IpingException(IpingFailure.session);
      }
      throw const IpingException(IpingFailure.unavailable);
    } on FormatException {
      throw const IpingException(IpingFailure.unavailable);
    } on TypeError {
      throw const IpingException(IpingFailure.unavailable);
    }
  }

  Future<IpingSiteConfig> siteConfig() => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$site/api/system/config/site',
    );
    final data = response.data;
    if (data == null) throw const FormatException('Missing site configuration');
    return IpingSiteConfig.fromJson(data, site: site);
  }, sessionStatusCodes: const {});

  Future<IpingAccount> redeemClientLogin({
    required String code,
    required String verifier,
  }) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$site/api/user/client-login/token',
      data: {'code': code, 'code_verifier': verifier},
      options: Options(followRedirects: false),
    );
    final data = response.data;
    if (data == null) throw const FormatException('Missing credentials');
    return IpingAccount.fromJson({
      'id': data['id'],
      'email': data['email'],
      'subscription_token': data['subscription_token'],
      'api_key': data['access_key'],
    });
  });

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final base = Uri.parse('$site/api/');
    final uri = base.resolve(path);
    if (uri.origin != base.origin || !uri.path.startsWith(base.path)) {
      throw ArgumentError.value(path, 'path', 'Expected an iPing API path');
    }
    final apiKey = _apiKey?.call();
    if (apiKey == null || !IpingAccount.isValidApiKey(apiKey)) {
      throw const IpingException(IpingFailure.session);
    }
    return _request(() async {
      final response = await _dio.get<T>(
        uri.toString(),
        queryParameters: queryParameters,
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          followRedirects: false,
        ),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Missing API response');
      return data;
    }, sessionStatusCodes: const {401});
  }

  Future<IpingUserInfo> userInfo() async =>
      IpingUserInfo.fromJson(await get<Map<String, dynamic>>('user/info'));

  Future<IpingReferralStats> referralStats() async =>
      IpingReferralStats.fromJson(
        await get<Map<String, dynamic>>('user/referral/stats'),
      );

  Future<IpingTrafficStats> trafficStats({DateTime? now}) async {
    final reportingTime = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 8),
    );
    final start = DateTime.utc(
      reportingTime.year,
      reportingTime.month,
      reportingTime.day,
    ).subtract(const Duration(days: 29));
    return IpingTrafficStats.fromJson(
      await get<List<dynamic>>(
        'tunnel/traffic/stats',
        queryParameters: {
          'aggregate_by': 'day',
          'start_date': start.toIso8601String(),
        },
      ),
      start: start,
    );
  }

  String subscriptionUrl(String token) => Uri.parse(
    '$site/api/tunnel/subscription',
  ).replace(queryParameters: {'token': token}).toString();

  Future<IpingSubscription> subscription(String url) => _request(() async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': 'iPing Clash.Meta',
          'Accept': 'text/yaml, text/plain',
        },
      ),
    );
    final content = response.data ?? '';
    return (
      bytes: Uint8List.fromList(utf8.encode(content)),
      nodes: await compute(ipingNodeCount, content),
    );
  });
}
