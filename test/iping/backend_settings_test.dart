import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/settings_native.dart';
import 'package:fl_clash/iping/settings_validation.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late IpingBackend backend;

  setUp(() {
    container = ProviderContainer();
    container.listen(ipingSettingsProvider, (_, _) {});
    backend = container.read(ipingBackendProvider);
  });
  tearDown(() => container.dispose());

  test(
    'settings observe native changes without owning another config',
    () async {
      final initial = await backend.readSettings();
      expect(initial.port('mixed-port'), defaultClashConfig.mixedPort);
      expect(initial.text('log-level'), defaultClashConfig.logLevel.name);

      container
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) =>
                state.copyWith(mixedPort: 7900, logLevel: LogLevel.debug),
          );
      final changed = await backend.readSettings();
      expect(changed.port('mixed-port'), 7900);
      expect(changed.text('log-level'), 'debug');
      expect(initial.port('mixed-port'), defaultClashConfig.mixedPort);
    },
  );

  test('a batch changes native config once and preserves overrides', () async {
    final before = defaultClashConfig.copyWith(
      mode: Mode.global,
      secret: 'controller-secret',
      dns: defaultDns.copyWith(enable: false),
      dnsOverrideKeys: {DnsOverrideKey.enable},
      tunOverrideKeys: {TunOverrideKey.mtu},
      tunOverride: defaultProfileTun.copyWith(mtu: 1280),
    );
    container.read(patchClashConfigProvider.notifier).value = before;
    final writes = <PatchClashConfig>[];
    container.listen(patchClashConfigProvider, (_, value) => writes.add(value));
    final hosts = {'example.com': '127.0.0.1'};
    await backend.updateSettings({
      'mixed-port': 7900,
      'port': 7901,
      'socks-port': 7902,
      'redir-port': 7903,
      'tproxy-port': 7904,
      'allow-lan': true,
      'ipv6': true,
      'unified-delay': false,
      'tcp-concurrent': false,
      'log-level': 'debug',
      'find-process-mode': 'always',
      'geodata-loader': 'standard',
      'global-ua': 'iPing/test',
      'hosts': hosts,
    });
    expect(writes, [
      before.copyWith(
        mixedPort: 7900,
        port: 7901,
        socksPort: 7902,
        redirPort: 7903,
        tproxyPort: 7904,
        allowLan: true,
        ipv6: true,
        unifiedDelay: false,
        tcpConcurrent: false,
        logLevel: LogLevel.debug,
        findProcessMode: FindProcessMode.always,
        geodataLoader: GeodataLoader.standard,
        globalUa: 'iPing/test',
        hosts: hosts,
      ),
    ]);
    hosts['example.com'] = '127.0.0.2';
    expect(
      container.read(patchClashConfigProvider).hosts['example.com'],
      '127.0.0.1',
    );
  });

  test(
    'invalid batches write nothing, including otherwise valid values',
    () async {
      final before = container.read(patchClashConfigProvider);
      for (final patch in <Map<String, Object?>>[
        {'ipv6': true, 'mixed-port': 0},
        {'ipv6': true, 'port': 80},
        {'ipv6': true, 'mixed-port': 49152},
        {'ipv6': true, 'port': before.mixedPort},
        {'ipv6': true, 'log-level': 'trace'},
        {'ipv6': true, 'find-process-mode': 'strict'},
        {'ipv6': true, 'allow-lan': 'true'},
        {'ipv6': true, 'global-ua': 'bad\nheader'},
        {
          'ipv6': true,
          'hosts': {'example.com': 127},
        },
        {'ipv6': true, 'dns.unknown': true},
      ]) {
        await expectLater(
          backend.updateSettings(patch),
          throwsA(isA<IpingSettingsException>()),
        );
        expect(container.read(patchClashConfigProvider), before);
      }
    },
  );

  test(
    'optional ports can be disabled and user agent can return to default',
    () async {
      await backend.updateSettings({'global-ua': 'iPing/test', 'port': 7901});
      await backend.updateSettings({
        'global-ua': null,
        'port': 0,
        'socks-port': 0,
      });
      expect(container.read(patchClashConfigProvider).globalUa, isNull);
      expect(container.read(patchClashConfigProvider).port, 0);
      await backend.updateSettings({'global-ua': ''});
      expect(container.read(patchClashConfigProvider).globalUa, isNull);
    },
  );

  test(
    'settings snapshots cannot mutate their source or nested collections',
    () {
      final hosts = {'example.com': '127.0.0.1'};
      final servers = ['https://example.com/dns-query'];
      final settings = IpingSettings({
        'hosts': hosts,
        'dns.nameserver': servers,
      });
      hosts.clear();
      servers.clear();
      expect(settings.stringMap('hosts'), {'example.com': '127.0.0.1'});
      expect(settings['dns.nameserver'], ['https://example.com/dns-query']);
      expect(() => settings.values.clear(), throwsUnsupportedError);
      expect(() => (settings['hosts']! as Map).clear(), throwsUnsupportedError);
      expect(
        () => (settings['dns.nameserver']! as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'DNS values distinguish an empty override from following a profile',
    () async {
      await backend.updateSettings({
        'dns.ipv6': false,
        'dns.fallback': <String>[],
        'dns.nameserver-policy': {'example.com': '1.1.1.1,8.8.8.8'},
        'dns.fallback-filter.geoip': false,
      });
      final before = container.read(patchClashConfigProvider);
      final snapshot = await backend.readSettings();
      expect(snapshot.overrides['dns.ipv6'], isTrue);
      expect(snapshot.overrides['dns.fallback'], isTrue);
      expect(
        before.dnsOverrideKeys,
        containsAll([
          DnsOverrideKey.ipv6,
          DnsOverrideKey.fallback,
          DnsOverrideKey.nameserverPolicy,
          DnsOverrideKey.fallbackFilterGeoip,
        ]),
      );
      expect(before.dns.fallbackFilter.geoip, isFalse);
      await backend.updateSettings({'dns.fallback': null});
      final after = container.read(patchClashConfigProvider);
      expect(after.dnsOverrideKeys, isNot(contains(DnsOverrideKey.fallback)));
      expect(after.dnsOverrideKeys, contains(DnsOverrideKey.ipv6));
      expect(after.dns.nameserverPolicy, before.dns.nameserverPolicy);
      expect(after.dns.fallbackFilter, before.dns.fallbackFilter);
      expect((await backend.readSettings()).overrides['dns.fallback'], isFalse);
      expect(() => snapshot.overrides.clear(), throwsUnsupportedError);
    },
  );

  test(
    'desktop TUN overrides preserve the service options and other keys',
    () async {
      final before = container.read(patchClashConfigProvider);
      await backend.updateSettings({
        'tun.mtu': 1400,
        'tun.dns-hijack': <String>[],
        'tun.enable': true,
        'tun.stack': 'system',
      });
      final changed = container.read(patchClashConfigProvider);
      expect(changed.tun.mtu, before.tun.mtu);
      expect(changed.tunOverride.mtu, 1400);
      expect(changed.tunOverride.dnsHijack, isEmpty);
      expect(changed.tun.enable, isTrue);
      expect(changed.tun.stack, TunStack.system);
      expect(changed.tunOverrideKeys, {
        TunOverrideKey.mtu,
        TunOverrideKey.dnsHijack,
      });
      await backend.updateSettings({'tun.mtu': null});
      final reset = container.read(patchClashConfigProvider);
      expect(reset.tunOverride.mtu, defaultProfileTun.mtu);
      expect(reset.tunOverrideKeys, {TunOverrideKey.dnsHijack});
      expect(reset.tun, changed.tun);
    },
  );

  test('mobile TUN edits go to VPN options and cannot follow a profile', () {
    final changed = applyNativeIpingSettings(defaultClashConfig, {
      'tun.mtu': 1400,
      'tun.route-address': ['10.0.0.0/8'],
      'tun.route-exclude-address': ['10.1.0.0/16'],
      'tun.stack': 'mips',
    }, desktop: false);
    expect(changed.tun.mtu, 1400);
    expect(changed.tun.routeAddress, ['10.0.0.0/8']);
    expect(changed.tun.routeExcludeAddress, ['10.1.0.0/16']);
    expect(changed.tun.stack, TunStack.mips);
    expect(changed.tunOverride, defaultClashConfig.tunOverride);
    expect(changed.tunOverrideKeys, isEmpty);
    expect(
      () =>
          applyNativeIpingSettings(changed, {'tun.mtu': null}, desktop: false),
      throwsA(isA<IpingSettingsException>()),
    );
  });

  test(
    'invalid DNS or TUN batches do not partly change valid settings',
    () async {
      final before = container.read(patchClashConfigProvider);
      for (final patch in <Map<String, Object?>>[
        {'ipv6': true, 'tun.mtu': 1279},
        {
          'ipv6': true,
          'tun.route-exclude-address': ['10.0.0.0/99'],
        },
        {
          'ipv6': true,
          'tun.include-uid': [-1],
        },
        {'ipv6': true, 'dns.listen': 'bad:0'},
        {
          'ipv6': true,
          'dns.nameserver': [7],
        },
        {'ipv6': true, 'dns.enhanced-mode': 'hosts'},
        {'ipv6': true, 'tun.stack': null},
      ]) {
        await expectLater(
          backend.updateSettings(patch),
          throwsA(isA<IpingSettingsException>()),
        );
        expect(container.read(patchClashConfigProvider), before);
      }
    },
  );

  test(
    'shared address checks accept IPv6 and reject malformed CIDRs and listeners',
    () {
      for (final cidr in ['10.0.0.0/8', '2001:db8::/32', '::/0']) {
        expect(isIpingCidr(cidr), isTrue, reason: cidr);
      }
      for (final cidr in [
        '10.0.0.0/33',
        '2001:db8::/129',
        '10.0.0.0/08',
        '010.0.0.0/8',
        '[::]/0',
        '::%eth0/64',
        'bad/1',
      ]) {
        expect(isIpingCidr(cidr), isFalse, reason: cidr);
      }
      expect(isIpingListen('[::]:1053'), isTrue);
      expect(isIpingListen('localhost:1053'), isTrue);
      expect(isIpingListen(':53'), isTrue);
      expect(isIpingListen('::1:1053'), isFalse);
      expect(isIpingListen('[::]:0'), isFalse);
    },
  );

  test('native DNS collections retain their existing size support', () async {
    final filters = List.generate(200, (index) => 'host$index.example.com');
    await backend.updateSettings({'dns.fake-ip-filter': filters});
    expect(container.read(patchClashConfigProvider).dns.fakeIpFilter, filters);
  });
}
