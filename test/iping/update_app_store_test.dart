import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/iping/update_app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Adapter implements HttpClientAdapter {
  Map<String, Object> body = {};
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/javascript; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final current = PackageInfo(
    appName: 'iPing',
    packageName: 'my.iping.client',
    version: '1.0.0',
    buildNumber: '2026102701',
  );
  const listing = {
    'bundleId': 'my.iping.client',
    'trackId': 123456789,
    'version': '1.1.0',
    'minimumOsVersion': '15.0',
    'releaseNotes': 'New version',
  };
  late _Adapter adapter;
  late IpingAppStoreUpdateClient client;

  setUp(() {
    adapter = _Adapter()
      ..body = {
        'resultCount': 1,
        'results': [listing],
      };
    client = IpingAppStoreUpdateClient(
      dio: Dio()..httpClientAdapter = adapter,
      country: 'hk',
      systemVersion: () async => '16.0',
    );
  });
  tearDown(() => client.close());

  test(
    'looks up the bundle ID and parses Apple JSON with a JavaScript MIME type',
    () async {
      final update = await client.check('ios-app-store', current);
      expect(adapter.request.uri.host, 'itunes.apple.com');
      expect(adapter.request.uri.path, '/lookup');
      expect(adapter.request.uri.queryParameters, {
        'bundleId': 'my.iping.client',
        'country': 'hk',
        'entity': 'software',
      });
      expect(update?.version, '1.1.0');
      expect(update?.notes, 'New version');
      expect(update?.isAppStore, isTrue);
      expect(update?.url.toString(), 'https://apps.apple.com/app/id123456789');
      expect(client.baseUrl, contains('country=hk'));
    },
  );

  for (final results in [
    <Map<String, Object>>[],
    [
      {...listing, 'bundleId': 'another.app'},
    ],
    [
      {...listing, 'version': '1.0.0'},
    ],
    [
      {...listing, 'version': '1.0'},
    ],
    [
      {...listing, 'version': '0.9.0'},
    ],
    [
      {...listing, 'minimumOsVersion': '17.0'},
    ],
  ]) {
    test(
      'does not require an unavailable or already installed update: $results',
      () async {
        adapter.body = {'resultCount': results.length, 'results': results};
        expect(await client.check('ios-app-store', current), isNull);
      },
    );
  }

  for (final invalid in [
    {...listing, 'trackId': 0},
    {...listing, 'version': '1.1.0-pre.1'},
  ]) {
    test('rejects invalid App Store metadata: $invalid', () async {
      adapter.body = {
        'resultCount': 1,
        'results': [invalid],
      };
      await expectLater(
        client.check('ios-app-store', current),
        throwsFormatException,
      );
    });
  }

  test('rejects malformed lookup results', () async {
    adapter.body = {'resultCount': 1};
    await expectLater(
      client.check('ios-app-store', current),
      throwsFormatException,
    );
  });
}
