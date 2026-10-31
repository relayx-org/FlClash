import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/account_statistics.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:fl_clash/iping/topup.dart';
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
  List<IpingTopupOrder> topups = [];
  IpingTopupOptions topupSettings = const IpingTopupOptions(
    payments: [IpingPayment(id: 3, name: 'Alipay', percentFee: 0.03)],
    activities: [
      IpingTopupActivity(percentage: true, value: 10, minAmount: 50),
    ],
    minAmount: 10,
  );
  IpingFailure? topupFailure;
  int? topupFailureStatus;
  final createdTopups = <({double price, int paymentId})>[];
  final cancelledTopups = <int>[];
  final topupPageRequests = <({int page, int perPage})>[];

  @override
  Future<IpingTopupPage> topupOrders({int page = 1, int perPage = 20}) async {
    topupPageRequests.add((page: page, perPage: perPage));
    final start = (page - 1) * perPage;
    return IpingTopupPage(
      topups.skip(start).take(perPage).toList(),
      topups.length,
    );
  }

  @override
  Future<IpingTopupOptions> topupOptions() async => topupSettings;

  @override
  Future<Uri> createTopup({
    required double price,
    required int paymentId,
  }) async {
    if (topupFailure case final failure?) {
      throw IpingException(failure, status: topupFailureStatus);
    }
    createdTopups.add((price: price, paymentId: paymentId));
    return Uri.parse('https://pay.example.com/order');
  }

  @override
  Future<void> cancelTopup(int id) async => cancelledTopups.add(id);

  String popupNoticeText = '';
  int popupNoticeRequests = 0;
  @override
  Future<String> popupNotice() async {
    popupNoticeRequests++;
    return popupNoticeText;
  }

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

  IpingFailure? nativeInventoryFailure;
  String? nativeInventoryMessage;
  final nativeInventory = <String, List<Object?>>{
    'ipproxy/inventory/native': [],
    'ipproxy/inventory/native2': [],
    'ipproxy/inventory/native3': [],
  };
  List<Object?> tunnelPrices = [];
  IpingFailure? tunnelPlansFailure;
  String? tunnelPlansMessage;
  final nativePurchases = <({String path, Map<String, dynamic> data})>[];
  IpingFailure? nativeBuyFailure;
  int? nativeBuyStatus;
  String? nativeBuyMessage;
  Map<String, dynamic> nativeBuyResponse = const {};
  List<Map<String, Object?>> tunnels = [];
  List<Map<String, Object?>> userProxiesList = [];
  final switchedIpTunnels = <int>[];
  IpingFailure? tunnelsFailure;
  String? tunnelsMessage;
  final tunnelQueries = <Map<String, dynamic>>[];
  final tunnelUpdates = <Map<String, dynamic>>[];
  final tunnelFills = <Map<String, dynamic>>[];
  final tunnelRenewals = <int>[];
  IpingFailure? tunnelActionFailure;
  String? tunnelActionMessage;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path == 'ipproxy') {
      return {'data': userProxiesList, 'total': userProxiesList.length} as T;
    }
    if (path == 'tunnel') {
      if (tunnelsFailure case final failure?) {
        throw IpingException(failure, message: tunnelsMessage);
      }
      final query = queryParameters ?? const <String, dynamic>{};
      tunnelQueries.add(Map<String, dynamic>.from(query));
      final now = DateTime.now();
      final name = query['name'];
      final status = query['status'];
      final expired = query['is_expired'];
      final tunnelType = query['tunnel_type'];
      final autoRenew = query['auto_renew'];
      final listenPort = query['listen_port'];
      final ipType = query['ip_type'];
      final id = query['id'];
      final page = query['page'] is num ? (query['page'] as num).toInt() : 1;
      final perPage = query['perPage'] is num
          ? (query['perPage'] as num).toInt()
          : 10;
      final matched = [
        for (final tunnel in tunnels)
          if (_tunnelVisible(
            tunnel,
            now: now,
            name: name is String ? name : null,
            status: status is String ? status : null,
            expired: expired is String ? expired : null,
            tunnelType: tunnelType is String ? tunnelType : null,
            autoRenew: autoRenew is String ? autoRenew : null,
            listenPort: listenPort is num ? listenPort.toInt() : null,
            ipType: ipType is String ? ipType : null,
            id: id is num ? id.toInt() : null,
          ))
            tunnel,
      ];
      final start = (page - 1) * perPage;
      final slice = start >= matched.length
          ? const <Map<String, Object?>>[]
          : matched.sublist(
              start,
              start + perPage > matched.length
                  ? matched.length
                  : start + perPage,
            );
      return {'data': slice, 'total': matched.length} as T;
    }
    if (path == 'tunnel/prices') {
      if (tunnelPlansFailure case final failure?) {
        throw IpingException(failure, message: tunnelPlansMessage);
      }
      return tunnelPrices as T;
    }
    if (path.startsWith('ipproxy/inventory/')) {
      if (nativeInventoryFailure case final failure?) {
        throw IpingException(failure, message: nativeInventoryMessage);
      }
      return (nativeInventory[path] ?? const <Object?>[]) as T;
    }
    throw UnimplementedError(path);
  }

  @override
  Future<T> post<T>(String path, {Object? data}) async {
    final switchPort = RegExp(r'^tunnel/(\d+)/switch-port$').firstMatch(path);
    if (switchPort != null) {
      final id = int.parse(switchPort.group(1)!);
      final tunnel = _tunnelById(id);
      final newPort = (tunnel?['listen_port'] as int? ?? 1000) + 1;
      if (tunnel != null) tunnel['listen_port'] = newPort;
      return {'listen_port': newPort} as T;
    }
    if (!path.startsWith('ipproxy/buy/')) throw UnimplementedError(path);
    nativePurchases.add((
      path: path,
      data: Map<String, dynamic>.from(data as Map),
    ));
    if (nativeBuyFailure case final failure?) {
      throw IpingException(
        failure,
        status: nativeBuyStatus,
        message: nativeBuyMessage,
      );
    }
    return nativeBuyResponse as T;
  }

  @override
  Future<void> postVoid(String path, {Object? data}) async {
    final switchIp = RegExp(r'^tunnel/(\d+)/switch-ip$').firstMatch(path);
    if (switchIp != null) {
      final id = int.parse(switchIp.group(1)!);
      switchedIpTunnels.add(id);
      return;
    }
    if (path == 'tunnel/batch/renew') {
      final body = Map<String, dynamic>.from(data as Map);
      if (tunnelActionFailure case final failure?) {
        throw IpingException(failure, message: tunnelActionMessage);
      }
      final ids = body['ids'];
      if (ids is List) {
        for (final id in ids) {
          if (id is num) {
            tunnelRenewals.add(id.toInt());
            final tunnel = _tunnelById(id.toInt());
            if (tunnel != null) {
              tunnel['expired_at'] = DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 30))
                  .toIso8601String();
            }
          }
        }
      }
      return;
    }
    final renew = RegExp(r'^tunnel/(\d+)/renew$').firstMatch(path);
    if (renew == null) throw UnimplementedError(path);
    final id = int.parse(renew.group(1)!);
    if (tunnelActionFailure case final failure?) {
      throw IpingException(failure, message: tunnelActionMessage);
    }
    tunnelRenewals.add(id);
    final tunnel = _tunnelById(id);
    if (tunnel != null) {
      tunnel['expired_at'] = DateTime.now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String();
    }
  }

  @override
  Future<void> patchVoid(String path, {Object? data}) async {
    final pool = RegExp(r'^sk5-pool/(\d+)$').firstMatch(path);
    if (pool != null) {
      final id = int.parse(pool.group(1)!);
      final tunnel = _tunnelById(id);
      if (tunnel != null && data is Map) {
        if (data['name'] is String) tunnel['name'] = data['name'] as String;
        if (data['country'] is String) {
          tunnel['sk5_pool_country'] = data['country'] as String;
        }
        if (data['interval_minutes'] is num) {
          tunnel['sk5_pool_interval_minutes'] = data['interval_minutes'] as num;
        }
      }
      return;
    }
    if (path == 'tunnel/batch/fill') {
      final body = Map<String, dynamic>.from(data as Map);
      tunnelFills.add(body);
      final items = body['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final id = item['id'];
            if (id is num) {
              final tunnel = _tunnelById(id.toInt());
              if (tunnel != null) {
                if (item['name'] is String) {
                  tunnel['name'] = item['name'] as String;
                }
                if (item['forward_addresses'] is Map) {
                  tunnel['forward_addresses'] = item['forward_addresses'];
                }
                if (item.containsKey('forward_addresses_protocol')) {
                  tunnel['forward_addresses_protocol'] =
                      item['forward_addresses_protocol'];
                }
              }
            }
          }
        }
      }
      return;
    }
    if (path != 'tunnel/batch/update') throw UnimplementedError(path);
    final body = Map<String, dynamic>.from(data as Map);
    if (tunnelActionFailure case final failure?) {
      throw IpingException(failure, message: tunnelActionMessage);
    }
    tunnelUpdates.add(body);
    final ids = body['ids'];
    if (ids is! List) return;
    for (final id in ids) {
      if (id is! num) continue;
      final tunnel = _tunnelById(id.toInt());
      if (tunnel == null) continue;
      if (body['status'] is String) tunnel['status'] = body['status'] as String;
      if (body['auto_renew'] is bool) {
        tunnel['auto_renew'] = body['auto_renew'] as bool;
      }
    }
  }

  Map<String, Object?>? _tunnelById(int id) {
    for (final tunnel in tunnels) {
      if (tunnel['id'] == id) return tunnel;
    }
    return null;
  }
}

bool _tunnelVisible(
  Map<String, Object?> tunnel, {
  required DateTime now,
  required String? name,
  required String? status,
  required String? expired,
  required String? tunnelType,
  required String? autoRenew,
  int? listenPort,
  String? ipType,
  required int? id,
}) {
  if (id != null && tunnel['id'] != id) return false;
  final tunnelName = tunnel['name'];
  if (name != null &&
      name.isNotEmpty &&
      (tunnelName is! String || !tunnelName.contains(name))) {
    return false;
  }
  if (status != null && tunnel['status'] != status) return false;
  if (tunnelType != null &&
      tunnelType.isNotEmpty &&
      tunnel['tunnel_type'] != tunnelType) {
    return false;
  }
  if (autoRenew != null && tunnel['auto_renew'] != (autoRenew == 'true')) {
    return false;
  }
  if (listenPort != null && tunnel['listen_port'] != listenPort) {
    return false;
  }
  if (ipType != null && ipType.isNotEmpty && tunnel['ip_type'] != ipType) {
    return false;
  }
  if (status != null && tunnel['status'] != status) return false;
  if (tunnelType != null &&
      tunnelType.isNotEmpty &&
      tunnel['tunnel_type'] != tunnelType) {
    return false;
  }
  if (autoRenew != null && tunnel['auto_renew'] != (autoRenew == 'true')) {
    return false;
  }
  final rawExpiry = tunnel['expired_at'];
  final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
  final isExpired = expiry != null && !expiry.isAfter(now);
  final longExpired =
      expiry != null && now.difference(expiry) > const Duration(days: 3);
  if (longExpired) return false;
  if (expired == 'true' && !isExpired) return false;
  if (expired == 'false' && isExpired) return false;
  return true;
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
