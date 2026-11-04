import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/iping/native_ip.dart';
import 'package:iping_openwrt/client.dart';
import 'package:iping_openwrt/iping_client.dart';

class _ProxyClient implements RouterClient {
  final requests = <(String, Map<String, Object?>)>[];

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    requests.add((method, args));
    if (method != 'api_call') return null;
    final path = args['path'] as String;
    if (path == 'ipproxy/inventory/native') {
      return {
        'status': 200,
        'body': [
          {
            'country_code': 'JP',
            'country': 'Japan',
            'city_name': 'Tokyo',
            'city': 'tokyo',
            'number': 2,
            'price': 9,
            'tags': [],
          },
        ],
      };
    }
    if (path.startsWith('ipproxy/inventory/')) {
      return {'status': 200, 'body': <Object?>[]};
    }
    return {
      'status': 404,
      'body': {'message': 'not found'},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the router client proxies store requests through the agent', () async {
    final client = _ProxyClient();
    final api = createRouterIpingClient(client, () => 'https://example.com');

    late final List<NativeIpOffer> offers;
    offers = await api.nativeIpInventory();

    expect(offers.single.place, 'Japan · Tokyo');
    expect(client.requests.first.$1, 'api_call');
    expect(client.requests.first.$2['path'], 'ipproxy/inventory/native');
    expect(client.requests.first.$2['method'], 'GET');
    expect(
      api.subscriptionUrl('token'),
      'https://example.com/api/tunnel/subscription?token=token',
    );
  });
}
