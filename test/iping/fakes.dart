import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/account_statistics.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:fl_clash/iping/user_info.dart';

class FakeIpingApi extends IpingApi {
  FakeIpingApi({super.site});

  IpingSiteConfig siteSettings = const IpingSiteConfig();
  Completer<IpingSiteConfig>? siteRequest;
  bool siteFails = false;
  int siteRequests = 0;
  IpingFailure? subscriptionFailure;
  Completer<IpingSubscription>? download;
  int userId = 7;
  int nodes = 2;
  int downloads = 0;
  String? subscriptionUrlRequested;
  IpingFailure? userInfoFailure;
  Completer<IpingUserInfo>? userInfoRequest;
  int userInfoRequests = 0;
  double balance = 128.5;
  String status = 'active';
  bool? telegramBound = true;
  Set<String>? notifications = const {'topup', 'tunnel_expiring'};
  IpingFailure? referralFailure;
  IpingFailure? trafficFailure;
  Completer<IpingReferralStats>? referralRequest;
  Completer<IpingTrafficStats>? trafficRequest;
  int referralRequests = 0;
  int trafficRequests = 0;
  @override
  Future<IpingReferralStats> referralStats() async {
    referralRequests++;
    if (referralFailure case final failure?) throw IpingException(failure);
    return referralRequest?.future ??
        IpingReferralStats(
          userId: userId,
          link: '$site?ref=$userId',
          count: 3,
          earnings: 29.9,
          commissionRate: 10,
        );
  }

  @override
  Future<IpingTrafficStats> trafficStats({DateTime? now}) async {
    trafficRequests++;
    if (trafficFailure case final failure?) throw IpingException(failure);
    return trafficRequest?.future ??
        IpingTrafficStats(
          List.generate(
            30,
            (i) => IpingTrafficDay(
              date: DateTime.utc(2026, 10, i + 1),
              actual: i == 29 ? 7.5 : 0,
              billed: i == 29 ? 9 : 0,
            ),
          ),
        );
  }

  @override
  Future<IpingUserInfo> userInfo() async {
    userInfoRequests++;
    if (userInfoFailure case final failure?) throw IpingException(failure);
    return userInfoRequest?.future ??
        IpingUserInfo(
          id: userId,
          email: 'user@example.com',
          balance: balance,
          status: status,
          telegramBound: telegramBound,
          notificationSubscriptions: notifications,
          createdAt: DateTime.utc(2026, 10, 22),
        );
  }

  @override
  Future<IpingSiteConfig> siteConfig() async {
    siteRequests++;
    if (siteFails) throw const IpingException(IpingFailure.unavailable);
    return siteRequest?.future ?? siteSettings;
  }

  Future<IpingAccount?> authenticate([bool register = false]) async =>
      IpingAccount(
        id: userId,
        email: 'user@example.com',
        subscriptionToken: 'subscription',
        apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
      );

  @override
  Future<IpingSubscription> subscription(String url) async {
    downloads++;
    subscriptionUrlRequested = url;
    if (subscriptionFailure case final failure?) throw IpingException(failure);
    return download?.future ?? (bytes: Uint8List(0), nodes: nodes);
  }
}

class MemorySessionStorage implements IpingSessionStorage {
  IpingStoredSession? stored;
  IpingAccount? get value => stored?.account;
  set value(IpingAccount? account) =>
      stored = account == null ? null : IpingStoredSession(account: account);
  bool readFails = false;
  bool clearFails = false;
  @override
  Future<IpingStoredSession?> read() async {
    if (readFails) throw StateError('keychain unavailable');
    return stored;
  }

  @override
  Future<void> write(IpingStoredSession session) async => stored = session;
  @override
  Future<void> clear() async {
    if (clearFails) throw StateError('keychain unavailable');
    stored = null;
  }
}

class MemoryProfileStorage implements IpingProfileStorage {
  IpingCachedProfile? value;
  int saves = 0;
  int stops = 0;
  bool stopFails = false;
  bool saveFails = false;
  Completer<void>? pendingSave;

  @override
  Future<IpingCachedProfile?> read() async => value;
  @override
  Future<IpingCachedProfile> save(
    String url,
    IpingSubscription subscription,
  ) async {
    saves++;
    await pendingSave?.future;
    if (saveFails) throw StateError('save failed');
    return value = (nodes: subscription.nodes, updated: DateTime(2026, 10, 22));
  }

  @override
  Future<void> clear() async => value = null;
  @override
  Future<void> stop() async {
    stops++;
    if (stopFails) throw StateError('stop failed');
  }
}
