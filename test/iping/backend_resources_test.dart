import 'package:fl_clash/iping/backend_resources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resource snapshots freeze definitions including nested options', () {
    final options = {
      'headers': <String, Object?>{'Host': 'example.com'},
    };
    final definition = <String, Object?>{
      'name': 'Home',
      'type': 'vmess',
      'ws-opts': options,
      'alpn': ['h2'],
    };
    final proxy = IpingCustomProxy(
      id: '12345678901234567890',
      definition: definition,
      emptyOptions: const ['alpn'],
    );
    (options['headers'] as Map)['Host'] = 'changed';
    expect(
      ((proxy.definition['ws-opts'] as Map)['headers'] as Map)['Host'],
      'example.com',
    );
    expect(
      () => (proxy.definition['alpn'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(IpingCustomProxy.fromJson(proxy.toJson()).emptyOptions, {'alpn'});
    expect(
      IpingCustomProxy.fromJson(proxy.toJson()).id,
      '12345678901234567890',
    );
  });

  test('catalogs reject duplicate names and invalid Core resources', () {
    final proxy = IpingCustomProxy(
      id: 'A',
      definition: const {'name': 'Home', 'type': 'direct'},
    );
    validateIpingCustomProxies([proxy]);
    for (final items in [
      [proxy, IpingCustomProxy(id: 'B', definition: proxy.definition)],
      [
        proxy,
        IpingCustomProxy(
          id: 'A',
          definition: const {'name': 'Other', 'type': 'direct'},
        ),
      ],
      [
        proxy.withDefinition(const {'name': 'DIRECT', 'type': 'direct'}),
      ],
      [
        proxy.withDefinition(const {'name': 'a,b', 'type': 'ss'}),
      ],
    ]) {
      expect(
        () => validateIpingCustomProxies(items),
        throwsA(isA<IpingResourceException>()),
      );
    }
    expect(
      () => validateIpingCustomProxies([proxy], limit: 0),
      throwsA(isA<IpingResourceException>()),
    );
  });

  test('rule provider validation shares URL, behavior and format rules', () {
    const provider = IpingRuleProvider(
      id: 'large-12345678901234567890',
      label: 'Ads',
      url: 'https://example.com/ads.yaml',
      behavior: 'domain',
    );
    validateIpingRuleProviders([provider], remoteOnly: true);
    expect(IpingRuleProvider.fromJson(provider.toJson()).id, provider.id);
    validateIpingRuleProviders([
      const IpingRuleProvider(id: 'local', label: 'Local'),
    ]);
    for (final value in [
      const IpingRuleProvider(id: 'local', label: 'Local'),
      const IpingRuleProvider(
        id: 'bad',
        label: 'Ads',
        url: 'https://example.com/a',
        format: 'mrs',
      ),
      const IpingRuleProvider(
        id: 'bad',
        label: 'Ads',
        url: 'https://example.com/a',
        behavior: 'bad',
      ),
    ]) {
      expect(
        () => validateIpingRuleProviders([value], remoteOnly: true),
        throwsA(isA<IpingResourceException>()),
      );
    }
    for (final address in [
      'file:///etc/shadow',
      'https://user:pass@example.com/a',
      'https://example.com/a#fragment',
      'https:///a',
    ]) {
      expect(isIpingProviderUrl(address), isFalse);
    }
  });
}
