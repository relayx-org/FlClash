import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  final requests = <RequestOptions>[];
  int status = 200;
  Object body = <String, dynamic>{};
  String requestBody = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    requests.add(options);
    if (requestStream != null) {
      requestBody = utf8.decode(
        await requestStream.fold<List<int>>(
          [],
          (bytes, chunk) => bytes..addAll(chunk),
        ),
      );
    }
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late IpingApi api;
  String? apiKey;
  setUp(() {
    adapter = _Adapter();
    apiKey = '62ab74aa-0473-4790-9bd5-2f728dd42c56';
    api = IpingApi(
      dio: Dio()..httpClientAdapter = adapter,
      apiKey: () => apiKey,
    );
  });

  test(
    'backend GET requests use the current API key only in the bearer header',
    () async {
      adapter.body = {'id': 7, 'email': 'user@example.com'};

      final user = await api.get<Map<String, dynamic>>('user/info');

      expect(user['id'], 7);
      expect(adapter.request.uri.toString(), '$ipingSite/api/user/info');
      expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
      expect(adapter.request.uri.queryParameters, isEmpty);
      expect(adapter.request.followRedirects, isFalse);

      apiKey = '908c6dd1-97d3-43ba-87bc-c7d6b7a1b63b';
      await api.get<Map<String, dynamic>>(
        'tunnel',
        queryParameters: {'page': 2},
      );
      expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
      expect(adapter.request.uri.queryParameters, {'page': '2'});

      apiKey = null;
      await expectLater(
        api.get<Map<String, dynamic>>('user/info'),
        throwsA(isA<IpingException>()),
      );
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'client login codes are redeemed with the verifier and no API key',
    () async {
      adapter.body = {
        'id': 7,
        'email': 'user@example.com',
        'subscription_token': 'subscription-token',
        'access_key': '908c6dd1-97d3-43ba-87bc-c7d6b7a1b63b',
      };

      final account = await api.redeemClientLogin(
        code: 'code',
        verifier: 'verifier',
      );

      expect(adapter.request.method, 'POST');
      expect(
        adapter.request.uri.toString(),
        '$ipingSite/api/user/client-login/token',
      );
      expect(adapter.request.headers['Authorization'], isNull);
      expect(adapter.request.followRedirects, isFalse);
      expect(jsonDecode(adapter.requestBody), {
        'code': 'code',
        'code_verifier': 'verifier',
      });
      expect(account.id, 7);
      expect(account.email, 'user@example.com');
      expect(account.subscriptionToken, 'subscription-token');
      expect(account.apiKey, '908c6dd1-97d3-43ba-87bc-c7d6b7a1b63b');
    },
  );

  test('an expired or reused client login code is a session failure', () async {
    adapter.status = 400;
    adapter.body = {'error': '授权码无效或已过期'};
    await expectLater(
      api.redeemClientLogin(code: 'code', verifier: 'verifier'),
      throwsA(
        isA<IpingException>().having(
          (e) => e.failure,
          'failure',
          IpingFailure.session,
        ),
      ),
    );
  });

  test(
    'user information uses authenticated API data and accepts zero balance',
    () async {
      adapter.body = {
        'id': 7,
        'email': 'user@example.com',
        'balance': 0,
        'status': 'active',
        'created_at': '2026-10-22T12:00:00Z',
        'api_key': 'subscription-token',
        'remarks': 'internal',
      };

      final user = await api.userInfo();

      expect(adapter.request.uri.path, '/api/user/info');
      expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
      expect(user.id, 7);
      expect(user.email, 'user@example.com');
      expect(user.balance, 0);
      expect(user.status, 'active');
      expect(user.createdAt, DateTime.utc(2026, 10, 22, 12));
    },
  );

  test('popup notice is read with the API key and blank means none', () async {
    adapter.body = {'POPUP_NOTICE': '  **Maintenance** tonight\n'};
    expect(await api.popupNotice(), '**Maintenance** tonight');
    expect(adapter.request.uri.path, '/api/system/config');
    expect(adapter.request.uri.queryParameters, {'name': 'POPUP_NOTICE'});
    expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');

    adapter.body = {'POPUP_NOTICE': null};
    expect(await api.popupNotice(), isEmpty);
  });

  test(
    'referral statistics retain website percentage and CNY earnings',
    () async {
      adapter.body = {
        'user_id': 7,
        'referral_link': '$ipingSite?ref=7',
        'referral_count': 3,
        'total_earnings': 29.9,
        'commission_rate': 10,
      };
      final stats = await api.referralStats();
      expect(adapter.request.uri.path, '/api/user/referral/stats');
      expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
      expect(stats.userId, 7);
      expect(stats.commissionRate, 10);
      expect(stats.earnings, 29.9);
    },
  );

  test(
    'traffic uses a 30-day UTC+08 reporting window and keeps GB units',
    () async {
      adapter.body = [
        {'date': '2026-10-23', 'traffic': 2.5, 'traffic_cost': 3},
        {'date': '2026-10-23', 'traffic': 1, 'traffic_cost': 2},
        {'date': '2026-10-24', 'traffic': 0.5, 'traffic_cost': 1},
      ];
      final stats = await api.trafficStats(now: DateTime.utc(2026, 10, 23, 17));
      expect(adapter.request.uri.path, '/api/tunnel/traffic/stats');
      expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
      expect(adapter.request.uri.queryParameters, {
        'aggregate_by': 'day',
        'start_date': '2026-09-25T00:00:00.000Z',
      });
      expect(stats.days, hasLength(30));
      expect(stats.actual, 4);
      expect(stats.billed, 6);
      expect(stats.days.last.date, DateTime.utc(2026, 10, 24));
      expect(stats.days.first.actual, 0);
    },
  );

  for (final key in [null, '', 'not-an-api-key', 'secret\r\nInjected: value']) {
    test(
      'missing or malformed API credentials never send an authenticated request',
      () async {
        apiKey = key;
        await expectLater(
          api.get<Map<String, dynamic>>('user/info'),
          throwsA(isA<IpingException>()),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }

  for (final path in [
    'https://other.example.com/api/user/info',
    '//other.example.com/api/user/info',
    '../outside',
    '/user/info',
  ]) {
    test(
      'authenticated requests reject paths outside the configured API: $path',
      () async {
        await expectLater(
          api.get<Map<String, dynamic>>(path),
          throwsArgumentError,
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }

  for (final status in [401, 403, 404, 503]) {
    test(
      'backend status $status preserves the distinction between authentication and service errors',
      () async {
        adapter.status = status;
        await expectLater(
          api.get<Map<String, dynamic>>('user/info'),
          throwsA(
            isA<IpingException>().having(
              (e) => e.failure,
              'failure',
              status == 401 ? IpingFailure.session : IpingFailure.unavailable,
            ),
          ),
        );
      },
    );
  }

  test('subscription tokens are encoded into the iPing subscription URL', () {
    final uri = Uri.parse(api.subscriptionUrl('subscription-key'));
    expect(uri.origin, ipingSite);
    expect(uri.path, '/api/tunnel/subscription');
    expect(uri.queryParameters, {'token': 'subscription-key'});
  });

  test(
    'site configuration is fetched anonymously and maps public fields',
    () async {
      adapter.body = {
        'SITE_NAME': 'Custom site',
        'SITE_DESCRIPTION': 'Site introduction',
        'LOGO_URL': '/logo.svg',
        'ALLOW_REGISTER': false,
        'CHATWOOT_TOKEN': 'unused',
      };

      final config = await api.siteConfig();

      expect(
        adapter.request.uri.toString(),
        '$ipingSite/api/system/config/site',
      );
      expect(adapter.request.headers.containsKey('Authorization'), isFalse);
      expect(adapter.request.uri.queryParameters, isEmpty);
      expect(config.name, 'Custom site');
      expect(config.description, 'Site introduction');
      expect(config.logoUrl, '$ipingSite/logo.svg');
      expect(config.allowRegister, isFalse);
      expect(config.toJson().containsKey('CHATWOOT_TOKEN'), isFalse);
    },
  );

  for (final status in [401, 403, 404, 503]) {
    test(
      'public configuration failure $status never expires a session',
      () async {
        adapter.status = status;

        await expectLater(
          api.siteConfig(),
          throwsA(
            isA<IpingException>().having(
              (error) => error.failure,
              'failure',
              IpingFailure.unavailable,
            ),
          ),
        );
      },
    );
  }

  test('revoked subscription credentials require another login', () async {
    adapter.status = 404;
    await expectLater(
      api.subscription(api.subscriptionUrl('revoked')),
      throwsA(
        isA<IpingException>().having(
          (e) => e.failure,
          'failure',
          IpingFailure.session,
        ),
      ),
    );
  });

  test(
    'subscription requests advertise Clash format and omit account auth',
    () async {
      adapter.body =
          'proxies:\n  - {name: node, type: ss, server: example.com, port: 443}\n';
      final subscription = await api.subscription(
        'https://iping.my/api/tunnel/subscription?token=key',
      );
      expect(subscription.nodes, 1);
      expect(adapter.request.followRedirects, isTrue);
      expect(adapter.request.headers['User-Agent'], contains('Clash'));
      expect(adapter.request.headers.containsKey('Authorization'), isFalse);
    },
  );

  for (final content in [
    '<html>Sign in</html>',
    'proxies: [',
    'rules: []',
    'proxies: [invalid]',
  ]) {
    test('rejects unusable subscription content: $content', () {
      expect(() => ipingNodeCount(content), throwsA(isA<IpingException>()));
    });
  }

  test('empty subscriptions are valid but have no usable nodes', () {
    expect(ipingNodeCount('proxies: []\n'), 0);
  });

  test(
    'transient service failures are distinguished from expired sessions',
    () async {
      adapter.status = 503;
      await expectLater(
        api.subscription(api.subscriptionUrl('key')),
        throwsA(
          isA<IpingException>().having(
            (e) => e.failure,
            'failure',
            IpingFailure.unavailable,
          ),
        ),
      );
    },
  );
}
