import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'account_statistics.dart';
import 'auth_session.dart';
import 'browser.dart';
import 'session.dart';
import 'site_config.dart';
import 'native_ip.dart';
import 'topup.dart';
import 'user_info.dart';

final ipingApiProvider = Provider<IpingApi>((ref) => IpingApi());
final ipingAuthenticatedApiProvider = Provider<IpingApi>(
  (ref) => ref
      .watch(ipingApiProvider)
      .withApiKey(() => ref.read(ipingSessionProvider).account?.apiKey),
);
final ipingSiteConfigProvider =
    NotifierProvider<IpingSiteConfigNotifier, IpingSiteConfig>(
      IpingSiteConfigNotifier.new,
    );
final ipingBrowserProvider = Provider<IpingBrowserLogin>((ref) {
  final api = ref.watch(ipingApiProvider);
  final browser = IpingBrowserLogin(
    site: api.site,
    exchange: api.redeemClientLogin,
    session: ipingSystemAuthSession(),
  );
  ref.onDispose(browser.cancel);
  return browser;
});
final ipingStorageProvider = Provider<IpingSessionStorage>(
  (ref) => _SecureSessionStorage(),
);
final ipingProfilesProvider = Provider<IpingProfileStorage>(
  (ref) => _ManagedProfileStorage(ref),
);
final ipingSessionProvider =
    NotifierProvider<IpingSessionNotifier, IpingSessionState>(
      IpingSessionNotifier.new,
    );
final ipingUserInfoProvider = FutureProvider.autoDispose<IpingUserInfo?>((
  ref,
) async {
  final account = ref.watch(ipingSessionProvider.select((s) => s.account));
  if (account?.apiKey == null) return null;
  final info = await ref.watch(ipingAuthenticatedApiProvider).userInfo();
  if (info.id != account!.id) {
    throw const IpingException(IpingFailure.session);
  }
  return info;
}, retry: (_, _) => null);

final ipingRecentTopupsProvider = FutureProvider.autoDispose<IpingTopupPage?>((
  ref,
) {
  final account = ref.watch(ipingSessionProvider.select((s) => s.account));
  if (account?.apiKey == null) return Future.value(null);
  return ref.watch(ipingAuthenticatedApiProvider).topupOrders(perPage: 10);
}, retry: (_, _) => null);

final ipingTopupOptionsProvider = FutureProvider.autoDispose<IpingTopupOptions>(
  (ref) => ref.watch(ipingAuthenticatedApiProvider).topupOptions(),
  retry: (_, _) => null,
);

final ipingNativeIpInventoryProvider =
    FutureProvider.autoDispose<List<NativeIpOffer>>(
      (ref) => ref.watch(ipingAuthenticatedApiProvider).nativeIpInventory(),
      retry: (_, _) => null,
    );

final ipingTunnelPlansProvider = FutureProvider.autoDispose<List<TunnelPlan>>(
  (ref) => ref.watch(ipingAuthenticatedApiProvider).tunnelPlans(),
  retry: (_, _) => null,
);

final ipingReferralStatsProvider = FutureProvider.autoDispose
    .family<IpingReferralStats?, IpingAccount>((ref, account) async {
      final current = ref.watch(ipingSessionProvider.select((s) => s.account));
      if (current != account || account.apiKey == null) return null;
      final stats = await ref
          .watch(ipingAuthenticatedApiProvider)
          .referralStats();
      if (stats.userId != account.id) {
        throw const IpingException(IpingFailure.session);
      }
      return stats;
    }, retry: (_, _) => null);

final ipingTrafficStatsProvider = FutureProvider.autoDispose
    .family<IpingTrafficStats?, IpingAccount>((ref, account) {
      final current = ref.watch(ipingSessionProvider.select((s) => s.account));
      if (current != account || account.apiKey == null) {
        return Future.value(null);
      }
      return ref.watch(ipingAuthenticatedApiProvider).trafficStats();
    }, retry: (_, _) => null);

final ipingDnsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final host = Uri.parse(ref.watch(ipingApiProvider).site).host;
  try {
    return (await InternetAddress.lookup(
      host,
    ).timeout(const Duration(seconds: 5))).isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}, retry: (_, _) => null);

class IpingSiteConfigNotifier extends Notifier<IpingSiteConfig> {
  Future<void>? _pending;
  bool _cacheLoaded = false;
  int _generation = 0;

  @override
  IpingSiteConfig build() {
    ref.watch(ipingApiProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    _pending = null;
    _cacheLoaded = false;
    unawaited(Future.microtask(refresh));
    return const IpingSiteConfig();
  }

  Future<void> refresh() {
    if (!ref.mounted) return Future.value();
    if (_pending != null) return _pending!;
    late final Future<void> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
    return _pending = operation;
  }

  Future<void> _refresh() async {
    final generation = _generation;
    final api = ref.read(ipingApiProvider);
    final key = 'my.iping.client.site:${api.site}';
    SharedPreferences? cache;
    try {
      cache = await SharedPreferences.getInstance();
      if (!ref.mounted || generation != _generation) return;
      if (!_cacheLoaded) {
        _cacheLoaded = true;
        final value = cache.getString(key);
        if (value != null) {
          state = IpingSiteConfig.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
            site: api.site,
          );
        }
      }
    } catch (_) {
      _cacheLoaded = true;
    }
    if (!ref.mounted || generation != _generation) return;
    try {
      final config = await api.siteConfig();
      if (!ref.mounted || generation != _generation) return;
      state = config;
      await cache?.setString(key, jsonEncode(config.toJson()));
    } catch (_) {
      commonPrint.log('Unable to refresh site configuration');
    }
  }
}

class IpingSessionNotifier extends Notifier<IpingSessionState> {
  late IpingSession controller;

  @override
  IpingSessionState build() {
    controller = IpingSession(
      api: ref.watch(ipingApiProvider),
      authenticate: (register) =>
          register && !ref.read(ipingSiteConfigProvider).allowRegister
          ? Future.value(null)
          : ref.read(ipingBrowserProvider).signIn(register: register),
      cancelAuthentication: ref.read(ipingBrowserProvider).cancel,
      storage: ref.watch(ipingStorageProvider),
      profiles: ref.watch(ipingProfilesProvider),
      onChanged: (next) {
        if (ref.mounted) state = next;
      },
    );
    ref.onDispose(controller.dispose);
    return const IpingSessionState();
  }

  Future<void> synchronize() {
    unawaited(ref.read(ipingSiteConfigProvider.notifier).refresh());
    return controller.synchronize();
  }
}

class _SecureSessionStorage implements IpingSessionStorage {
  static const _key = 'my.iping.client.subscription';
  // The app uses its own login Keychain items, without cross-app sharing.
  // Data Protection Keychain groups require a provisioning profile on macOS.
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: 'my.iping.client',
      usesDataProtectionKeychain: false,
    ),
  );

  @override
  Future<IpingStoredSession?> read() async {
    if (await _storage.read(key: 'my.iping.client.session') != null) {
      await _storage.delete(key: 'my.iping.client.session');
    }
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return decodeIpingSession(value);
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(IpingStoredSession session) =>
      _storage.write(key: _key, value: encodeIpingSession(session));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class _ManagedProfileStorage implements IpingProfileStorage {
  _ManagedProfileStorage(this.ref);
  final Ref ref;

  Profile? get _profile => ref
      .read(profilesProvider)
      .where((profile) => profile.label == 'iPing')
      .firstOrNull;

  @override
  Future<IpingCachedProfile?> read() async {
    final profile = _profile;
    if (profile == null) return null;
    final path = await appPath.getProfilePath(profile.id.toString());
    final file = File(path);
    if (!await file.exists()) return null;
    final nodes = await compute(ipingNodeCount, await file.readAsString());
    await app?.setConnectionAllowed(nodes > 0);
    return (nodes: nodes, updated: profile.lastUpdateDate);
  }

  @override
  Future<IpingCachedProfile> save(
    String url,
    IpingSubscription subscription,
  ) async {
    final previous = _profile;
    final candidate = (previous ?? Profile.normal(label: 'iPing', url: url))
        .copyWith(url: url, autoUpdate: false);
    final saved = await candidate.saveFile(
      subscription.bytes,
      validate: (path, key) =>
          ref.read(coreHandlerProvider).validateProfile(path, key),
    );
    final latest = _profile;
    final updated = latest != null && latest.id == saved.id
        ? latest.copyWith(
            url: saved.url,
            autoUpdate: saved.autoUpdate,
            lastUpdateDate: saved.lastUpdateDate,
          )
        : saved;
    await ref.read(profilesProvider.notifier).putAsync(updated);
    ref.read(currentProfileIdProvider.notifier).value = saved.id;
    await ref.read(setupActionProvider.notifier).applyProfile(silence: true);
    await app?.setConnectionAllowed(subscription.nodes > 0);
    return (nodes: subscription.nodes, updated: saved.lastUpdateDate);
  }

  @override
  Future<void> stop() async {
    await app?.setConnectionAllowed(false);
    await ref.read(setupActionProvider.notifier).setRunning(false);
  }

  @override
  Future<void> clear() async {
    await app?.setConnectionAllowed(false);
    ref.read(currentProfileIdProvider.notifier).value = null;
    for (final profile in ref.read(profilesProvider).toList()) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profile.id);
    }
    ref.read(currentProfileIdProvider.notifier).value = null;
    await ref.read(setupActionProvider.notifier).applyProfile(silence: true);
  }
}
