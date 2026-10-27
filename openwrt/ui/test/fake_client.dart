import 'dart:async';

import 'package:iping_openwrt/client.dart';

class FakeRouterClient implements RouterClient {
  FakeRouterClient({this.signedIn = true}) {
    sourceSettings.addAll(settings);
    for (final key in settings.keys) {
      if ((key.startsWith('dns.') || key.startsWith('tun.')) &&
          !const {
            'tun.enable',
            'tun.device',
            'dns.enable',
            'dns.listen',
          }.contains(key)) {
        settingOverrides[key] = false;
      }
    }
  }

  @override
  void exportText(String name, String content) {}

  Map<String, Object?> preferences = {};
  @override
  Map<String, Object?> readPreferences() => preferences;
  @override
  void writePreferences(Map<String, Object?> value) => preferences = value;

  bool signedIn;
  bool manualSubscription = false;
  String? subscriptionUrl;
  Completer<void>? importRequest;
  bool failImport = false;
  String resourceProfileId = 'source/7';
  bool running = true;
  final started = DateTime.now().subtract(const Duration(minutes: 5));
  String mode = 'rule';
  bool failMode = false;
  final filterErrors = <String, String>{};
  Completer<void>? modeRequest;
  bool fail = false;
  String selected = 'Node A';
  final calls = <String>[];
  final requests = <(String, Map<String, Object?>)>[];
  String? jobError;
  bool failSettings = false;
  final sourceSettings = <String, Object?>{};
  final settingOverrides = <String, bool>{};
  Map<String, Object?> settings = {
    'allow-lan': true,
    'ipv6': false,
    'mixed-port': 7890,
    'port': 0,
    'socks-port': 0,
    'redir-port': 7891,
    'tproxy-port': 7892,
    'global-ua': 'clash.meta',
    'log-level': 'info',
    'find-process-mode': 'off',
    'geodata-loader': 'standard',
    'dns.enable': true,
    'dns.use-hosts': true,
    'dns.listen': '127.0.0.1:1053',
    'dns.enhanced-mode': 'fake-ip',
    'dns.nameserver': ['https://1.1.1.1/dns-query'],
    'custom.bindings': {
      'proxies': <String>[],
      'providers': <String>[],
      'filters': <String>[],
      'rules': <String>[],
      'script': null,
    },
    'custom.rules': <Object?>[],
    'custom.scripts': <Object?>[],
    'custom.proxies': <Object?>[],
    'custom.rule-providers': <Object?>[],
    'custom.filters': <Object?>[],
  };
  Completer<void>? login;

  @override
  Future<Object?> call(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    calls.add(method);
    requests.add((method, args));
    if (method == 'settings_set') {
      if (args['profile_id'] != null &&
          args['profile_id'] != resourceProfileId) {
        throw const RouterException('resource_changed');
      }
      if (failSettings) throw const RouterException('storage_error');
      if (jobError == null) {
        for (final entry in Map<String, Object?>.from(
          args['changes'] as Map,
        ).entries) {
          final scoped = settingOverrides.containsKey(entry.key);
          settings[entry.key] = scoped && entry.value == null
              ? sourceSettings[entry.key]
              : entry.value;
          if (scoped) settingOverrides[entry.key] = entry.value != null;
        }
      }
    }
    if (fail && method != 'status') {
      throw const RouterException('network_error');
    }
    if (method == 'import_subscription') {
      if (importRequest case final request?) await request.future;
      if (failImport) throw const RouterException('invalid_subscription');
      if (jobError == null) {
        manualSubscription = true;
        subscriptionUrl = args['url'] as String;
        resourceProfileId = 'manual/fixture';
      }
    }
    if (method == 'set_mode') {
      if (failMode) throw const RouterException('storage_error');
      if (modeRequest case final pending?) await pending.future;
      mode = args['mode']! as String;
    }
    return switch (method) {
      'probe_route' => {
        'core-epoch': running ? 1 : 0,
        'picks-version': 1,
        'picks': {'PROXY': selected},
        'proxied': running,
      },
      'outbound_ip' => {
        'url': 'https://www.cloudflare.com/cdn-cgi/trace',
        'body': 'ip=203.0.113.7\nloc=US\n',
        'core-epoch': running ? 1 : 0,
        'picks-version': 1,
      },
      'service_check' => [
        {
          'name': (args['names'] as List).first,
          'status': 'available',
          'delay': 42,
          'region': 'US',
          'checked-at': 1700000000000,
          'core-epoch': running ? 1 : 0,
          'picks-version': 1,
        },
      ],
      'ip_quality' => {
        'status': 200,
        'body': '{"ip":"203.0.113.7","type":"hosting","aso":"Test network"}',
      },
      'dashboard' => {
        'local_ip': '192.168.1.1',
        'started': running ? started.millisecondsSinceEpoch : 0,
        'counts': {'groups': 1, 'proxies': 2, 'rules': 3},
        'settings': {
          for (final key in ['allow-lan', 'mixed-port', 'tun.enable'])
            key: settings[key],
        },
      },
      'validate_scripts' => [for (final _ in args['scripts']! as List) ''],
      'validate_proxies' => [for (final _ in args['proxies']! as List) ''],
      'validate_filters' => [
        for (final expression in args['filters']! as List)
          filterErrors[expression as String] ?? '',
      ],
      'status' => {
        'logged_in': signedIn,
        'manual_subscription': manualSubscription,
        'running': running,
        'busy': false,
        'nodes': 2,
        'email': 'user@example.com',
        'site': 'https://iping.my',
        'job': {'done': true, if (jobError != null) 'error': jobError},
      },
      'telemetry' => {
        'running': running,
        'upload': running ? 1024 : 0,
        'download': running ? 2048 : 0,
        'connections': running ? 1 : 0,
        'memory': running ? 1000000 : 0,
        'mode': mode,
      },
      'settings_get' => {
        'values': settings,
        'overrides': settingOverrides,
        'profile_id': resourceProfileId,
      },
      'account' => {
        'id': 7,
        'email': 'user@example.com',
        'balance': 128.5,
        'status': 'active',
      },
      'proxies' => {
        'groups': [
          {'name': 'PROXY', 'type': 'Selector', 'now': selected},
        ],
        'group': 'PROXY',
        'total': 2,
        'offset': 0,
        'items': [
          for (final name in ['Node A', 'Node B'])
            {
              'name': name,
              'type': 'Shadowsocks',
              'history': [
                {'delay': 30},
              ],
            },
        ],
      },
      'connections' => {'total': 0, 'items': []},
      'logs' => {'lines': []},
      'select_proxy' => _select(args['name'] as String),
      'connect' => _run(true),
      'disconnect' => _run(false),
      'logout' => _logout(),
      'delay_proxy' => {'delay': 42},
      _ => null,
    };
  }

  Object? _select(String name) {
    selected = name;
    return null;
  }

  Object? _run(bool value) {
    running = value;
    return null;
  }

  Object? _logout() {
    signedIn = false;
    manualSubscription = false;
    subscriptionUrl = null;
    running = false;
    return null;
  }

  @override
  Future<void> signIn({bool register = false}) async {
    calls.add('sign_in');
    if (login != null) await login!.future;
    if (login == null) {
      signedIn = true;
      manualSubscription = false;
      subscriptionUrl = null;
    }
  }

  @override
  void cancelSignIn() {
    if (login case final pending? when !pending.isCompleted) pending.complete();
  }

  @override
  void open(String url) => calls.add('open:$url');
}
