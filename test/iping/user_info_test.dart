import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/account_statistics.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/user_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const _account = IpingAccount(
  id: 7,
  email: 'user@example.com',
  subscriptionToken: 'subscription',
  apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
);

class _Backend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int userId = 7;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final subscription = options.uri.path == '/api/tunnel/subscription';
    return ResponseBody.fromString(
      subscription
          ? 'proxies: []'
          : jsonEncode(switch (options.uri.path) {
              '/api/user/referral/stats' => {
                'user_id': userId,
                'referral_link': 'https://account.example.com?ref=$userId',
                'referral_count': 3,
                'total_earnings': 29.9,
                'commission_rate': 10,
              },
              '/api/tunnel/traffic/stats' => [],
              _ => {
                'id': userId,
                'email': 'user@example.com',
                'balance': 42.5,
                'status': 'active',
                'created_at': '2026-10-22T00:00:00Z',
              },
            }),
      200,
      headers: {
        Headers.contentTypeHeader: [
          subscription ? 'text/yaml' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unknown optional fields remain unknown without inventing account data',
    () {
      final info = IpingUserInfo.fromJson({
        'id': 7,
        'email': 'user@example.com',
        'balance': -1.5,
        'created_at': 'invalid date',
      });
      expect(info.balance, -1.5);
      expect(info.status, isEmpty);
      expect(info.createdAt, isNull);
    },
  );

  for (final invalid in <Map<String, dynamic>>[
    {'id': 0},
    {'email': ''},
    {'balance': null},
    {'balance': '0'},
    {'balance': double.infinity},
    {'balance': double.nan},
  ]) {
    test('malformed required user information is rejected: $invalid', () {
      expect(
        () => IpingUserInfo.fromJson({
          'id': 7,
          'email': 'user@example.com',
          'balance': 0,
          ...invalid,
        }),
        throwsFormatException,
      );
    });
  }

  test(
    'production session and authenticated API share transport without a dependency cycle',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = _Backend();
      final api = IpingApi(
        dio: Dio()..httpClientAdapter = backend,
        site: 'https://account.example.com',
      );
      final storage = MemorySessionStorage()..value = _account;
      final container = ProviderContainer(
        overrides: [
          ipingApiProvider.overrideWithValue(api),
          ipingStorageProvider.overrideWithValue(storage),
          ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(ipingUserInfoProvider, (_, _) {});
      final session = container.read(ipingSessionProvider.notifier).controller;

      await session.initialize();
      final info = await container.read(ipingUserInfoProvider.future);

      expect(info?.id, _account.id);
      expect(info?.balance, 42.5);
      final request = backend.requests.singleWhere(
        (r) => r.uri.path == '/api/user/info',
      );
      expect(request.uri.origin, api.site);
      expect(request.headers['Authorization'], 'Bearer ${_account.apiKey}');
      expect(
        backend.requests
            .where((r) => r.uri.path != '/api/user/info')
            .every((r) => !r.headers.containsKey('Authorization')),
        isTrue,
      );

      final referralProvider = ipingReferralStatsProvider(_account);
      final trafficProvider = ipingTrafficStatsProvider(_account);
      container.listen(referralProvider, (_, _) {});
      container.listen(trafficProvider, (_, _) {});
      expect((await container.read(referralProvider.future))?.count, 3);
      expect((await container.read(trafficProvider.future))?.actual, 0);
      expect(
        backend.requests
            .where((r) => r.uri.path != '/api/tunnel/subscription')
            .every(
              (r) => r.headers['Authorization'] == 'Bearer ${_account.apiKey}',
            ),
        isTrue,
      );

      const nextKey = '908c6dd1-97d3-43ba-87bc-c7d6b7a1b63b';
      final authenticated = container.read(ipingAuthenticatedApiProvider);
      backend.userId = 8;
      storage.value = const IpingAccount(
        id: 8,
        email: 'other@example.com',
        subscriptionToken: 'other-subscription',
        apiKey: nextKey,
      );
      await session.initialize();
      expect((await container.read(ipingUserInfoProvider.future))?.id, 8);
      expect(backend.requests.last.headers['Authorization'], 'Bearer $nextKey');
      expect(
        container.read(ipingAuthenticatedApiProvider),
        same(authenticated),
      );

      await session.signOut();
      expect(await container.read(ipingUserInfoProvider.future), isNull);
      final requestCount = backend.requests.length;
      await expectLater(
        authenticated.userInfo(),
        throwsA(isA<IpingException>()),
      );
      expect(backend.requests.length, requestCount);
    },
  );

  group('user information provider', () {
    late FakeIpingApi api;
    late MemorySessionStorage storage;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      api = FakeIpingApi();
      storage = MemorySessionStorage()..value = _account;
      container = ProviderContainer(
        overrides: [
          ipingApiProvider.overrideWithValue(api),
          ipingAuthenticatedApiProvider.overrideWithValue(api),
          ipingStorageProvider.overrideWithValue(storage),
          ipingProfilesProvider.overrideWithValue(MemoryProfileStorage()),
        ],
      );
      container.listen(ipingUserInfoProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    Future<void> initialize() =>
        container.read(ipingSessionProvider.notifier).controller.initialize();

    test('signed-out and legacy accounts never request private data', () async {
      expect(await container.read(ipingUserInfoProvider.future), isNull);
      storage.value = const IpingAccount(
        id: 7,
        email: 'user@example.com',
        subscriptionToken: 'subscription',
      );
      await initialize();
      expect(await container.read(ipingUserInfoProvider.future), isNull);
      expect(api.userInfoRequests, 0);
    });

    test(
      'subscription refresh does not refetch unrelated user information',
      () async {
        await initialize();
        expect(
          (await container.read(ipingUserInfoProvider.future))?.balance,
          128.5,
        );

        await container.read(ipingSessionProvider.notifier).synchronize();

        expect((await container.read(ipingUserInfoProvider.future))?.id, 7);
        expect(api.userInfoRequests, 1);
      },
    );

    test(
      'statistics for a legacy or superseded account never send requests',
      () async {
        await initialize();
        final other = IpingAccount(
          id: 8,
          email: 'other@example.com',
          subscriptionToken: 'other',
          apiKey: _account.apiKey,
        );
        final referrals = ipingReferralStatsProvider(other);
        final traffic = ipingTrafficStatsProvider(other);
        container.listen(referrals, (_, _) {});
        container.listen(traffic, (_, _) {});
        expect(await container.read(referrals.future), isNull);
        expect(await container.read(traffic.future), isNull);
        expect(api.referralRequests, 0);
        expect(api.trafficRequests, 0);
      },
    );

    test(
      'statistics from a signed-out account are discarded even when responses arrive late',
      () async {
        await initialize();
        final account = container.read(ipingSessionProvider).account!;
        final referral = api.referralRequest = Completer<IpingReferralStats>();
        final traffic = api.trafficRequest = Completer<IpingTrafficStats>();
        final referrals = ipingReferralStatsProvider(account);
        final traffics = ipingTrafficStatsProvider(account);
        container.listen(referrals, (_, _) {});
        container.listen(traffics, (_, _) {});
        expect(api.referralRequests, 1);
        expect(api.trafficRequests, 1);
        await container
            .read(ipingSessionProvider.notifier)
            .controller
            .signOut();
        expect(await container.read(referrals.future), isNull);
        expect(await container.read(traffics.future), isNull);
        referral.complete(
          IpingReferralStats(
            userId: account.id,
            link: 'https://example.com?ref=7',
            count: 999,
            earnings: 999,
            commissionRate: 10,
          ),
        );
        traffic.complete(const IpingTrafficStats([]));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(referrals).value, isNull);
        expect(container.read(traffics).value, isNull);
      },
    );

    test('referral statistics cannot belong to another account', () async {
      await initialize();
      api.userId = 8;
      final provider = ipingReferralStatsProvider(
        container.read(ipingSessionProvider).account!,
      );
      container.listen(provider, (_, _) {});
      await expectLater(
        container.read(provider.future),
        throwsA(isA<IpingException>()),
      );
    });

    test('a different user response requires reauthorization', () async {
      api.userId = 8;
      await initialize();
      await expectLater(
        container.read(ipingUserInfoProvider.future),
        throwsA(
          isA<IpingException>().having(
            (error) => error.failure,
            'failure',
            IpingFailure.session,
          ),
        ),
      );
    });

    test('sign-out discards a private response that arrives late', () async {
      final request = api.userInfoRequest = Completer<IpingUserInfo>();
      await initialize();
      expect(container.read(ipingUserInfoProvider).isLoading, isTrue);
      await container.read(ipingSessionProvider.notifier).controller.signOut();
      expect(await container.read(ipingUserInfoProvider.future), isNull);

      request.complete(
        const IpingUserInfo(
          id: 7,
          email: 'old@example.com',
          balance: 123,
          status: 'active',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ipingUserInfoProvider).value, isNull);
      expect(container.read(ipingSessionProvider).account, isNull);
    });

    test('switching accounts ignores the previous pending response', () async {
      final request = api.userInfoRequest = Completer<IpingUserInfo>();
      await initialize();
      container.read(ipingUserInfoProvider);
      storage.value = const IpingAccount(
        id: 8,
        email: 'other@example.com',
        subscriptionToken: 'other-subscription',
        apiKey: '908c6dd1-97d3-43ba-87bc-c7d6b7a1b63b',
      );
      api.userInfoRequest = null;
      api.userId = 8;
      await initialize();
      expect((await container.read(ipingUserInfoProvider.future))?.id, 8);

      request.complete(
        const IpingUserInfo(
          id: 7,
          email: 'old@example.com',
          balance: 123,
          status: 'active',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ipingUserInfoProvider).value?.id, 8);
    });
  });
}
