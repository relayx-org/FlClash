import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../common/package.dart';
import 'update.dart';

const ipingAppStoreCountry = String.fromEnvironment(
  'IPING_APP_STORE_COUNTRY',
  defaultValue: 'us',
);

class IpingAppStoreUpdateClient extends IpingUpdateClient {
  IpingAppStoreUpdateClient({
    super.dio,
    this.country = ipingAppStoreCountry,
    Future<String> Function()? systemVersion,
  }) : _systemVersion = systemVersion ?? _iosVersion,
       super(baseUrl: 'https://itunes.apple.com/lookup?country=$country');

  final String country;
  final Future<String> Function() _systemVersion;

  @override
  Future<IpingUpdate?> check(String target, PackageInfo current) async {
    final response = await dio.get<String>(
      'https://itunes.apple.com/lookup',
      queryParameters: {
        'bundleId': current.packageName,
        'country': country,
        'entity': 'software',
      },
      options: Options(
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Cache-Control': 'no-cache'},
      ),
    );
    final data = jsonDecode(response.data ?? '') as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null) {
      throw const FormatException('Missing App Store results');
    }
    final matching = results.whereType<Map>().where(
      (item) => item['bundleId'] == current.packageName,
    );
    final app = matching.firstOrNull;
    if (app == null) return null;
    final id = app['trackId'] as int;
    if (id <= 0) throw const FormatException('Invalid App Store ID');
    final minimumOs = app['minimumOsVersion'] as String?;
    if (minimumOs != null &&
        compareVersions(minimumOs, await _systemVersion()) > 0) {
      return null;
    }
    final update = IpingUpdate.fromJson({
      'version': app['version'],
      'buildNumber': 0,
      'url': 'https://apps.apple.com/app/id$id',
      'sha256': '',
      'size': 0,
      'format': 'app-store',
      'notes': app['releaseNotes'] as String? ?? '',
    });
    return update.isNewerThan(current) ? update : null;
  }
}

Future<String> _iosVersion() async =>
    (await DeviceInfoPlugin().iosInfo).systemVersion;
