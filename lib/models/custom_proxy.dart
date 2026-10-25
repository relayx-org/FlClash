import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../common/snowflake.dart';
import '../enum/proxy_field.dart';

export '../enum/proxy_field.dart';

part 'generated/custom_proxy.freezed.dart';
part 'generated/custom_proxy.g.dart';

/// The `type` values `adapter.ParseProxy` accepts, in its own order.
const customProxyTypes = [
  'ss',
  'ssr',
  'socks5',
  'http',
  'vmess',
  'vless',
  'snell',
  'trojan',
  'hysteria',
  'hysteria2',
  'wireguard',
  'tuic',
  'shadowquic',
  'gost-relay',
  'direct',
  'dns',
  'reject',
  'rematch',
  'ssh',
  'mieru',
  'anytls',
  'sudoku',
  'masque',
  'trusttunnel',
  'openvpn',
  'tailscale',
  'zerotier',
  'easytier',
];

/// The standard methods of sing-shadowsocks2, which mihomo's ss adapter
/// creates its cipher with.
const _ssCiphers = [
  'aes-128-gcm',
  'aes-192-gcm',
  'aes-256-gcm',
  'chacha20-ietf-poly1305',
  'xchacha20-ietf-poly1305',
  '2022-blake3-aes-128-gcm',
  '2022-blake3-aes-256-gcm',
  '2022-blake3-chacha20-poly1305',
  'aes-128-ctr',
  'aes-192-ctr',
  'aes-256-ctr',
  'aes-128-cfb',
  'aes-192-cfb',
  'aes-256-cfb',
  'rc4-md5',
  'chacha20-ietf',
  'xchacha20',
  'chacha20',
  'none',
];

/// ShadowsocksR takes stream ciphers only.
const _ssrCiphers = [
  'aes-128-ctr',
  'aes-192-ctr',
  'aes-256-ctr',
  'aes-128-cfb',
  'aes-192-cfb',
  'aes-256-cfb',
  'rc4-md5',
  'chacha20-ietf',
  'xchacha20',
  'chacha20',
  'none',
];

const _choiceEquality = ListEquality<String>();

/// mihomo matches struct keys, like HTTP header names, in any case.
Object? _keyIn(Map map, String key) {
  if (map.containsKey(key)) {
    return key;
  }
  final lower = key.toLowerCase();
  for (final candidate in map.keys) {
    if (candidate.toString().toLowerCase() == lower) {
      return candidate;
    }
  }
  return null;
}

Map<String, dynamic> _withPath(Map map, List<String> path, Object? value) {
  final [key, ...rest] = path;
  final next = Map<String, dynamic>.from(map);
  final existing = _keyIn(next, key) as String? ?? key;
  final child = rest.isEmpty
      ? value
      : _withPath(
          switch (next[existing]) {
            final Map map => map,
            _ => const {},
          },
          rest,
          value,
        );
  if (child == null || child == '' || child is Map && child.isEmpty) {
    next.remove(existing);
  } else {
    next[existing] = child;
  }
  return next;
}

/// One app-level proxy, kept as the raw mapping the core parses, since each
/// proxy type reads its own set of keys.
@freezed
abstract class CustomProxy with _$CustomProxy {
  const factory CustomProxy({
    @JsonKey(fromJson: Snowflake.buildId) required int id,
    @Default({}) Map<String, dynamic> definition,
    String? order,

    /// Options the form lists with no value yet, which [definition] cannot
    /// hold since the core reads every key in it.
    @Default({}) Set<ProxyField> emptyOptions,
  }) = _CustomProxy;

  factory CustomProxy.fromJson(Map<String, Object?> json) =>
      _$CustomProxyFromJson(json);

  factory CustomProxy.fromDefinition(Map definition, {int? id}) {
    return CustomProxy(
      id: id ?? snowflake.id,
      definition: Map<String, dynamic>.from(definition),
    );
  }
}

extension CustomProxyExt on CustomProxy {
  String get name => definition['name']?.toString() ?? '';

  String get type => definition['type']?.toString() ?? '';

  String? get server => definition['server']?.toString();

  int? get port => switch (definition['port']) {
    final int port => port,
    final Object port => int.tryParse(port.toString()),
    null => null,
  };

  String? get address {
    final server = this.server;
    if (server == null || server.isEmpty) {
      return null;
    }
    final port = this.port;
    return port == null ? server : '$server:$port';
  }

  List<String> get searchFields => [name, type, ?server];

  Set<String> get requiredKeys => switch (type) {
    'ss' => const {'server', 'port', 'password', 'cipher'},
    'ssr' => const {'server', 'port', 'password', 'cipher', 'obfs', 'protocol'},
    'vmess' => const {'server', 'port', 'uuid', 'alterId', 'cipher'},
    'vless' => const {'server', 'port', 'uuid'},
    'snell' => const {'server', 'port', 'psk'},
    'trojan' || 'anytls' => const {'server', 'port', 'password'},
    'hysteria' => const {'server', 'up', 'down'},
    'hysteria2' => const {'server'},
    'wireguard' => const {'private-key'},
    'ssh' => const {'server', 'port', 'username'},
    'mieru' => const {'server', 'transport', 'username', 'password'},
    'sudoku' => const {'server', 'port', 'key'},
    'masque' => const {'server', 'port', 'private-key', 'public-key'},
    'openvpn' => const {'server', 'port', 'ca'},
    'zerotier' => const {'network'},
    'socks5' ||
    'http' ||
    'tuic' ||
    'shadowquic' ||
    'gost-relay' ||
    'trusttunnel' => const {'server', 'port'},
    _ => const {},
  };

  /// The rows the form always shows: the credentials and [requiredKeys].
  List<ProxyField> get fields => switch (type) {
    'ss' => const [ProxyField.cipher, ProxyField.password],
    'ssr' => const [
      ProxyField.cipher,
      ProxyField.protocol,
      ProxyField.obfs,
      ProxyField.password,
    ],
    'vmess' => const [ProxyField.cipher, ProxyField.alterId, ProxyField.uuid],
    'vless' => const [ProxyField.uuid],
    'tuic' => const [ProxyField.uuid, ProxyField.password],
    'trojan' || 'anytls' || 'hysteria2' => const [ProxyField.password],
    'hysteria' => const [ProxyField.up, ProxyField.down, ProxyField.authStr],
    'snell' => const [ProxyField.psk],
    'sudoku' => const [ProxyField.key],
    'wireguard' ||
    'masque' => const [ProxyField.privateKey, ProxyField.publicKey],
    'mieru' => const [
      ProxyField.transport,
      ProxyField.username,
      ProxyField.password,
    ],
    'socks5' ||
    'http' ||
    'ssh' ||
    'shadowquic' ||
    'trusttunnel' ||
    'gost-relay' ||
    'openvpn' => const [ProxyField.username, ProxyField.password],
    _ => const [],
  };

  /// The username, password and UUID among [fields], which tell one account
  /// on a server from another.
  List<ProxyField> get credentials => [
    for (final field in fields)
      if (const {
        ProxyField.username,
        ProxyField.password,
        ProxyField.uuid,
      }.contains(field))
        field,
  ];

  /// The keys the form adds one at a time, each left to the core's default
  /// until then.
  List<ProxyField> get options {
    final fields = this.fields;
    return [
      for (final field in ProxyField.values)
        if (!fields.contains(field) && _offers(field)) field,
    ];
  }

  bool _offers(ProxyField field) {
    final type = this.type;
    return switch (field) {
      ProxyField.username ||
      ProxyField.password ||
      ProxyField.uuid ||
      ProxyField.psk ||
      ProxyField.key ||
      ProxyField.publicKey ||
      ProxyField.authStr ||
      ProxyField.cipher ||
      ProxyField.alterId ||
      ProxyField.transport => false,
      ProxyField.privateKey || ProxyField.privateKeyPassphrase => type == 'ssh',
      ProxyField.preSharedKey || ProxyField.allowedIps => type == 'wireguard',
      ProxyField.obfs ||
      ProxyField.up ||
      ProxyField.down => type == 'hysteria2',
      ProxyField.obfsPassword =>
        type == 'hysteria2' && valueOf(ProxyField.obfs) != null,
      ProxyField.protocol || ProxyField.obfsSecret => type == 'hysteria',
      ProxyField.network => choicesOf(field).isNotEmpty,
      ProxyField.flow => type == 'vless',
      ProxyField.wsPath || ProxyField.wsHost => _usesNetwork('ws'),
      ProxyField.grpcServiceName => _usesNetwork('grpc'),
      ProxyField.xhttpPath || ProxyField.xhttpHost => _usesNetwork('xhttp'),
      ProxyField.tls => const {
        'socks5',
        'http',
        'vmess',
        'vless',
        'gost-relay',
      }.contains(type),
      ProxyField.sni => const {
        'http',
        'trojan',
        'hysteria',
        'hysteria2',
        'tuic',
        'shadowquic',
        'gost-relay',
        'anytls',
        'masque',
        'trusttunnel',
      }.contains(type),
      ProxyField.servername => type == 'vmess' || type == 'vless',
      ProxyField.alpn => const {
        'vmess',
        'vless',
        'trojan',
        'hysteria',
        'hysteria2',
        'tuic',
        'shadowquic',
        'anytls',
        'trusttunnel',
      }.contains(type),
      ProxyField.skipCertVerify => const {
        'socks5',
        'http',
        'vmess',
        'vless',
        'trojan',
        'hysteria',
        'hysteria2',
        'tuic',
        'gost-relay',
        'anytls',
        'masque',
        'trusttunnel',
      }.contains(type),
      ProxyField.clientFingerprint => const {
        'ss',
        'vmess',
        'vless',
        'snell',
        'trojan',
        'gost-relay',
        'anytls',
        'trusttunnel',
      }.contains(type),
      ProxyField.realityPublicKey || ProxyField.realityShortId => const {
        'vmess',
        'vless',
        'trojan',
      }.contains(type),
      ProxyField.plugin || ProxyField.udpOverTcp => type == 'ss',
      ProxyField.pluginMode => type == 'ss' && _pluginReads('mode'),
      ProxyField.pluginHost => type == 'ss' && _pluginReads('host'),
      ProxyField.protocolParam || ProxyField.obfsParam => type == 'ssr',
      ProxyField.obfsMode ||
      ProxyField.obfsHost ||
      ProxyField.version => type == 'snell',
      ProxyField.ports ||
      ProxyField.hopInterval => type == 'hysteria' || type == 'hysteria2',
      ProxyField.congestionController => const {
        'tuic',
        'shadowquic',
        'masque',
        'trusttunnel',
      }.contains(type),
      ProxyField.udpRelayMode || ProxyField.reduceRtt => type == 'tuic',
      ProxyField.ip ||
      ProxyField.ipv6 ||
      ProxyField.dns ||
      ProxyField.remoteDnsResolve ||
      ProxyField.mtu => type == 'wireguard' || type == 'masque',
      ProxyField.tfo || ProxyField.mptcp => !const {
        'dns',
        'reject',
        'rematch',
        'hysteria',
        'hysteria2',
        'tuic',
        'wireguard',
        'shadowquic',
        'masque',
        'tailscale',
        'zerotier',
        'easytier',
      }.contains(type),
      ProxyField.interfaceName ||
      ProxyField.routingMark ||
      ProxyField.ipVersion => !const {
        'dns',
        'reject',
        'rematch',
      }.contains(type),
    };
  }

  bool _pluginReads(String key) => switch (valueOf(ProxyField.plugin)) {
    'obfs' || 'v2ray-plugin' || 'gost-plugin' => true,
    'kcptun' => key == 'mode',
    'shadow-tls' || 'restls' || 'jls' => key == 'host',
    _ => false,
  };

  bool _usesNetwork(String network) =>
      valueOf(ProxyField.network) == network &&
      choicesOf(ProxyField.network).contains(network);

  /// The values the core accepts, in the order the form lists them.
  List<String> choicesOf(ProxyField field) => switch (field) {
    ProxyField.cipher => switch (type) {
      'ss' => _ssCiphers,
      'ssr' => _ssrCiphers,
      'vmess' => const [
        'auto',
        'aes-128-gcm',
        'chacha20-poly1305',
        'aes-128-cfb',
        'none',
        'zero',
      ],
      _ => const [],
    },
    ProxyField.protocol => switch (type) {
      'ssr' => const [
        'origin',
        'auth_sha1_v4',
        'auth_aes128_md5',
        'auth_aes128_sha1',
        'auth_chain_a',
        'auth_chain_b',
      ],
      'hysteria' => const ['udp', 'wechat-video', 'faketcp'],
      _ => const [],
    },
    ProxyField.obfs => switch (type) {
      'ssr' => const [
        'plain',
        'http_simple',
        'http_post',
        'random_head',
        'tls1.2_ticket_auth',
        'tls1.2_ticket_fastauth',
      ],
      'hysteria2' => const ['salamander', 'gecko'],
      _ => const [],
    },
    ProxyField.transport => const ['TCP', 'UDP'],
    ProxyField.network => switch (type) {
      'vmess' => const ['tcp', 'ws', 'http', 'h2', 'grpc', 'mekya', 'mkcp'],
      'vless' => const ['tcp', 'ws', 'http', 'h2', 'grpc', 'xhttp'],
      'trojan' => const ['tcp', 'ws', 'grpc'],
      _ => const [],
    },
    ProxyField.flow => const ['xtls-rprx-vision'],
    ProxyField.clientFingerprint => const [
      'chrome',
      'firefox',
      'safari',
      'ios',
      'android',
      'edge',
      '360',
      'qq',
      'random',
      'chrome120',
      'firefox120',
      'safari16',
      'none',
    ],
    ProxyField.plugin => const [
      'obfs',
      'v2ray-plugin',
      'gost-plugin',
      'shadow-tls',
      'restls',
      'jls',
      'kcptun',
    ],
    ProxyField.obfsMode => const ['http', 'tls', 'shadow-tls', 'restls', 'jls'],
    ProxyField.congestionController => const [
      'cubic',
      'new_reno',
      'bbr',
      'bbr_meta_v1',
      'bbr_meta_v2',
    ],
    ProxyField.udpRelayMode => const ['native', 'quic'],
    ProxyField.ipVersion => [
      for (final version in IpVersion.values) version.value,
    ],
    _ => const [],
  };

  Object? valueOf(ProxyField field) {
    Object? value = definition;
    for (final key in field.path) {
      if (value is! Map) {
        return null;
      }
      value = value[_keyIn(value, key)];
    }
    return value;
  }

  /// Drops the key on an empty [value], with any map left empty and the
  /// options only the old value made available.
  CustomProxy withField(ProxyField field, Object? value) {
    final offered = options;
    var next = copyWith(definition: _withPath(definition, field.path, value));
    final stillOffered = next.options;
    for (final option in offered) {
      if (!stillOffered.contains(option)) {
        next = next.copyWith(
          definition: _withPath(next.definition, option.path, null),
        );
      }
    }
    return next;
  }

  /// Keeps the values the new type reads alike and fills the ones nearly
  /// every server of it takes.
  CustomProxy withType(String type) {
    if (type == this.type) {
      return this;
    }
    var next = withValue('type', type);
    for (final field in ProxyField.values) {
      final value = next.valueOf(field);
      if (value == null) {
        continue;
      }
      final choices = next.choicesOf(field);
      final readsAlike =
          (next.fields.contains(field) || next.options.contains(field)) &&
          (_choiceEquality.equals(choicesOf(field), choices) ||
              choices.contains(value));
      if (!readsAlike) {
        next = next.withField(field, null);
      }
    }
    final defaults = switch (type) {
      'vmess' => const {ProxyField.cipher: 'auto', ProxyField.alterId: 0},
      'mieru' => const {ProxyField.transport: 'TCP'},
      _ => const <ProxyField, Object>{},
    };
    for (final MapEntry(:key, :value) in defaults.entries) {
      if (next.valueOf(key) == null) {
        next = next.withField(key, value);
      }
    }
    return next;
  }

  List<String> stringsOf(String key) =>
      switch (definition[_keyIn(definition, key)]) {
        final List items => [for (final item in items) item.toString()],
        final String item when item.isNotEmpty => [item],
        _ => const [],
      };

  CustomProxy withValue(String key, Object? value) =>
      copyWith(definition: _withPath(definition, [key], value));
}
