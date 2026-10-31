import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/country_continent.dart';
import 'package:fl_clash/iping/native_ip.dart';
import 'package:fl_clash/iping/tunnel.dart';
import 'package:fl_clash/iping/topup.dart';
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

class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter(this.bodies);
  final Map<String, Object> bodies;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(bodies[options.uri.path]),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

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

  test('top-up orders are paged with the API key', () async {
    adapter.body = {
      'data': [
        {
          'id': 12,
          'price': 50,
          'bonus': 5,
          'status': 'pending',
          'order_id': 'T123',
          'pay_url': 'https://pay.example.com/T123',
          'created_at': '2026-10-30T08:00:00Z',
          'payment': {'name': 'Alipay'},
          'user': {'email': 'user@example.com'},
        },
      ],
      'total': 21,
    };
    final page = await api.topupOrders(page: 2, perPage: 20);
    expect(adapter.request.uri.path, '/api/topup');
    expect(adapter.request.uri.queryParameters, {'page': '2', 'perPage': '20'});
    expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
    expect(page.total, 21);
    final order = page.orders.single;
    expect(order.price, 50);
    expect(order.bonus, 5);
    expect(order.status, IpingTopupStatus.pending);
    expect(order.paymentName, 'Alipay');
    expect(order.payUrl, 'https://pay.example.com/T123');
  });

  test('top-up orders post the price, payment and a site redirect', () async {
    adapter.body = {'pay_url': 'https://pay.example.com/T1'};
    final url = await api.createTopup(price: 30, paymentId: 3);
    expect(adapter.request.method, 'POST');
    expect(adapter.request.uri.path, '/api/topup');
    expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
    expect(jsonDecode(adapter.requestBody), {
      'price': 30.0,
      'payment_id': 3,
      'redirect_url': '$ipingSite/account?trade_status=TRADE_SUCCESS',
    });
    expect(url, Uri.parse('https://pay.example.com/T1'));

    adapter.body = {'pay_url': 'javascript:alert(1)'};
    await expectLater(
      api.createTopup(price: 30, paymentId: 3),
      throwsA(isA<IpingException>()),
    );

    adapter.status = 409;
    adapter.body = {'error': '存在未完成的充值订单'};
    await expectLater(
      api.createTopup(price: 30, paymentId: 3),
      throwsA(isA<IpingException>().having((e) => e.status, 'status', 409)),
    );
  });

  test('cancelling a top-up accepts an empty 204 response', () async {
    adapter.status = 204;
    adapter.body = '';
    await api.cancelTopup(12);
    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.uri.path, '/api/topup/12/cancel');
    expect(adapter.request.headers['Authorization'], 'Bearer $apiKey');
  });

  test('top-up options combine payments, activities and the minimum', () async {
    final bodies = {
      '/api/pay': [
        {
          'id': 3,
          'name': 'Alipay',
          'percent_fee': 0.03,
          'fixed_fee': null,
          'icon': '/alipay.svg',
        },
        {'id': 4, 'name': 'WeChat', 'icon': 'javascript:alert(1)'},
      ],
      '/api/topup/activities': [
        {'type': 'percentage', 'value': 10, 'min_amount': 50},
        {'type': 'fixed', 'value': 5, 'min_amount': 100, 'max_amount': 300},
      ],
      '/api/system/config': {'MIN_TOPUP_AMOUNT': 10},
    };
    api = IpingApi(
      dio: Dio()..httpClientAdapter = _RoutedAdapter(bodies),
      apiKey: () => apiKey,
    );
    final options = await api.topupOptions();
    expect(options.minAmount, 10);
    expect(options.payments.first.percentFee, 0.03);
    expect(options.payments.first.icon, '$ipingSite/alipay.svg');
    expect(options.payments.last.icon, isEmpty);
    expect(options.bonusFor(30), 0);
    expect(options.bonusFor(50), 5);
    expect(options.bonusFor(100), 15);
    expect(options.bonusFor(500), 50);
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
    'native IP inventory merges every line and keeps the list price',
    () async {
      final bodies = {
        '/api/ipproxy/inventory/native': [
          {
            'country_code': 'US',
            'country': ' United States ',
            'city_name': ' Los Angeles ',
            'city': 'los-angeles',
            'number': 2,
            'price': 12.5,
            'tags': [
              {
                'key': 'residential',
                'label': ' Residential ',
                'tone': 'residential',
              },
              {'label': '  '},
              {'label': 1},
              {'key': '', 'label': 'Plain', 'tone': '  '},
            ],
          },
          'not-an-offer',
        ],
        '/api/ipproxy/inventory/native2': [
          {
            'country_code': 'JP',
            'country': 'Japan',
            'city_name': 'Tokyo',
            'city': 'tokyo',
            'number': 0,
            'price': 9,
            'tags': [],
          },
        ],
        '/api/ipproxy/inventory/native3': [
          {
            'country_code': 'US',
            'country': 'United States',
            'city_name': 'Seattle',
            'city': 'seattle',
            'number': 4,
            'price': 8,
            'tags': [
              {'label': 'ISP'},
            ],
          },
        ],
      };
      api = IpingApi(
        dio: Dio()..httpClientAdapter = _RoutedAdapter(bodies),
        apiKey: () => apiKey,
      );

      final offers = await api.nativeIpInventory();

      expect(offers.map((offer) => offer.line), [
        NativeIpLine.b,
        NativeIpLine.a,
        NativeIpLine.c,
      ]);
      expect(offers.map((offer) => offer.place), [
        'Japan · Tokyo',
        'United States · Los Angeles',
        'United States · Seattle',
      ]);
      expect(offers[1].stock, 2);
      expect(offers[1].price, 12.5);
      expect(offers[1].city, 'los-angeles');
      expect(offers[1].tags.map((tag) => (tag.key, tag.label, tag.tone)), [
        ('residential', 'Residential', 'residential'),
        ('Plain', 'Plain', null),
      ]);
      expect(offers[2].tags.single.key, 'ISP');
      expect(offers[0].stock, 0);
    },
  );

  test('country codes use the store continents', () {
    expect(continentOfCountryCode('US'), 'NA');
    expect(continentOfCountryCode('us'), 'NA');
    expect(continentOfCountryCode('USA'), 'NA');
    expect(continentOfCountryCode('JP'), 'AS');
    expect(continentOfCountryCode('GB'), 'EU');
    expect(continentOfCountryCode('BR'), 'SA');
    expect(continentOfCountryCode('AU'), 'OC');
    expect(continentOfCountryCode('ZA'), 'AF');
    expect(continentOfCountryCode('AQ'), 'AN');
    expect(continentOfCountryCode('ZZ'), 'other');
    expect(continentOfCountryCode(''), 'other');
    expect(nativeIpContinentsOf(['JP', 'US', 'ZZ', 'BR']), ['NA', 'SA', 'AS']);
  });

  test('tunnel plans drop trials and blank descriptions', () async {
    adapter.body = [
      {
        'id': 1,
        'name': 'Trial',
        'price': 0,
        'traffic': 1,
        'type': 'trial',
        'description': 'free',
      },
      {
        'id': 2,
        'name': 'Standard',
        'price': 6.5,
        'traffic': 500,
        'type': 'standard',
        'description': '  Monthly  ',
      },
      {'id': 3, 'name': 'Blank', 'price': 1, 'traffic': 1, 'type': 'standard'},
    ];

    final plans = await api.tunnelPlans();

    expect(adapter.request.uri.path, '/api/tunnel/prices');
    expect(plans.map((plan) => plan.id), [2, 3]);
    expect(plans.first.description, 'Monthly');
    expect(plans.last.description, isNull);
    expect(plans.first.isTrial, isFalse);
  });

  test('buying a native IP sends the catalog fields and tunnel plan', () async {
    const offer = NativeIpOffer(
      line: NativeIpLine.b,
      countryCode: 'JP',
      country: 'Japan',
      cityName: 'Tokyo',
      city: 'tokyo',
      stock: 3,
      price: 9,
      tags: [],
    );
    adapter.body = {
      'order_no': 'N1',
      'ids': [9, 'later', 2.5],
      'tunnel_ids': [3, 4],
    };

    final order = await api.buyNativeIp(
      const NativeIpPurchase(
        offer: offer,
        months: 3,
        count: 2,
        tunnelPlanId: 8,
      ),
    );

    expect(adapter.request.method, 'POST');
    expect(adapter.request.uri.path, '/api/ipproxy/buy/native2');
    expect(jsonDecode(adapter.requestBody), {
      'day': 90,
      'country_code': 'JP',
      'country': 'Japan',
      'city': 'tokyo',
      'count': 2,
      'bandwidth': 0,
      'router_buy': false,
      'tunnel_price_id': 8,
    });
    expect(order.orderNo, 'N1');
    expect(order.ids, [9, 2]);
    expect(order.tunnelIds, [3, 4]);
    expect(order.delivered, isTrue);

    adapter.body = {'order_no': '', 'ids': []};
    final ipOnly = await api.buyNativeIp(
      const NativeIpPurchase(offer: offer, months: 1, count: 1),
    );
    expect(
      jsonDecode(adapter.requestBody).containsKey('tunnel_price_id'),
      isFalse,
    );
    expect(ipOnly.orderNo, isNull);
    expect(ipOnly.tunnelIds, isEmpty);
    expect(ipOnly.delivered, isFalse);
  });

  test('a refused native IP purchase keeps the backend reason', () async {
    const offer = NativeIpOffer(
      line: NativeIpLine.a,
      countryCode: 'US',
      country: 'United States',
      cityName: 'Los Angeles',
      city: 'los-angeles',
      stock: 1,
      price: 12,
      tags: [],
    );
    adapter.status = 400;
    adapter.body = {'error': ' 余额不足 '};

    await expectLater(
      api.buyNativeIp(
        const NativeIpPurchase(offer: offer, months: 1, count: 1),
      ),
      throwsA(
        isA<IpingException>()
            .having(
              (error) => error.failure,
              'failure',
              IpingFailure.unavailable,
            )
            .having((error) => error.status, 'status', 400)
            .having((error) => error.message, 'message', '余额不足'),
      ),
    );

    adapter.body = {'error': '  '};
    await expectLater(
      api.buyNativeIp(
        const NativeIpPurchase(offer: offer, months: 1, count: 1),
      ),
      throwsA(
        isA<IpingException>().having(
          (error) => error.message,
          'message',
          isNull,
        ),
      ),
    );
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

  test(
    'tunnel queries, renewal and status updates use the store routes',
    () async {
      adapter.body = {'data': [], 'total': 0};
      await api.tunnels(
        const IpingTunnelQuery(
          name: ' edge ',
          status: 'active',
          expired: false,
          page: 2,
          perPage: 50,
        ),
      );
      expect(adapter.request.method, 'GET');
      expect(adapter.request.uri.path, '/api/tunnel');
      expect(adapter.request.uri.queryParameters, {
        'page': '2',
        'perPage': '50',
        'name': 'edge',
        'status': 'active',
        'is_expired': 'false',
      });

      adapter.status = 204;
      adapter.body = '';
      await api.renewTunnel(4);
      expect(adapter.request.method, 'POST');
      expect(adapter.request.uri.path, '/api/tunnel/4/renew');

      await api.updateTunnel(4, status: 'inactive', autoRenew: false);
      expect(adapter.request.method, 'PATCH');
      expect(adapter.request.uri.path, '/api/tunnel/batch/update');
      expect(jsonDecode(adapter.requestBody), {
        'ids': [4],
        'status': 'inactive',
        'auto_renew': false,
      });
    },
  );
}
