import 'dart:convert';

const ipingNetworkOptions = {
  'dns.enhanced-mode': ['normal', 'redir-host', 'fake-ip'],
  'dns.cache-algorithm': ['lru', 'arc'],
  'dns.fake-ip-filter-mode': ['blacklist', 'whitelist', 'rule'],
  'tun.stack': ['system', 'gvisor', 'mixed'],
};

const _flags = {
  'disable-keep-alive',
  'dns.enable',
  'dns.ipv6',
  'dns.use-hosts',
  'dns.use-system-hosts',
  'dns.respect-rules',
  'dns.prefer-h3',
  'dns.direct-nameserver-follow-policy',
  'dns.fallback-lazy-query',
  'dns.fallback-filter.geoip',
  'tun.enable',
  'tun.gso',
  'tun.strict-route',
  'tun.disable-icmp-forwarding',
};

const _ranges = {
  'keep-alive-idle': (1, 3600),
  'keep-alive-interval': (1, 3600),
  'routing-mark': (0, 0xFFFFFFFF),
  'dns.ipv6-timeout': (0, 10000),
  'dns.listen-routing-mark': (0, 0xFFFFFFFF),
  'dns.cache-max-size': (1, 1048576),
  'dns.fake-ip-ttl': (1, 86400),
  'tun.mtu': (1280, 65535),
  'tun.gso-max-size': (1, 1048576),
  'tun.udp-timeout': (1, 0xFFFFFFFF),
};

const _lists = {
  'dns.nameserver',
  'dns.default-nameserver',
  'dns.fallback',
  'dns.proxy-server-nameserver',
  'dns.direct-nameserver',
  'dns.fake-ip-filter',
  'dns.fallback-filter.geosite',
  'dns.fallback-filter.ipcidr',
  'dns.fallback-filter.domain',
  'tun.dns-hijack',
  'tun.route-address',
  'tun.route-exclude-address',
  'tun.include-interface',
  'tun.exclude-interface',
};

final _lineBreak = RegExp(r'[\x00\r\n]');

bool? isIpingNetworkValueValid(
  String key,
  Object? value, {
  int? collectionLimit = 128,
}) {
  if (_flags.contains(key)) return value is bool;
  if (_ranges[key] case final range?) {
    return value is int && value >= range.$1 && value <= range.$2;
  }
  if (_lists.contains(key)) {
    if (value is! List ||
        collectionLimit != null && value.length > collectionLimit) {
      return false;
    }
    return value.every(
      (item) =>
          item is String &&
          item.isNotEmpty &&
          utf8.encode(item).length <= 2048 &&
          !_lineBreak.hasMatch(item) &&
          (!const {
                'tun.route-address',
                'tun.route-exclude-address',
                'dns.fallback-filter.ipcidr',
              }.contains(key) ||
              isIpingCidr(item)),
    );
  }
  if (const {
    'tun.include-uid',
    'tun.exclude-uid',
    'tun.exclude-src-port',
    'tun.exclude-dst-port',
  }.contains(key)) {
    final ports = key.endsWith('-port');
    return value is List &&
        (collectionLimit == null || value.length <= collectionLimit) &&
        value.every(
          (item) =>
              item is int &&
              item >= (ports ? 1 : 0) &&
              item <= (ports ? 65535 : 0xFFFFFFFF),
        );
  }
  if (key == 'dns.nameserver-policy' ||
      key == 'dns.proxy-server-nameserver-policy') {
    return value is Map<String, Object?> &&
        (collectionLimit == null || value.length <= collectionLimit) &&
        value.entries.every(
          (entry) =>
              entry.key.isNotEmpty &&
              utf8.encode(entry.key).length <= 255 &&
              entry.value is String &&
              utf8.encode(entry.value! as String).length <= 2048 &&
              !_lineBreak.hasMatch('${entry.key}${entry.value}'),
        );
  }
  if (key == 'dns.listen') {
    return value is String && (value.isEmpty || isIpingListen(value));
  }
  if (key == 'dns.fake-ip-range' || key == 'dns.fake-ip-range6') {
    return value is String &&
        (key.endsWith('range6') && value.isEmpty || isIpingCidr(value));
  }
  if (key == 'tun.device' ||
      key == 'tun.congestion-controller' ||
      key == 'dns.fallback-filter.geoip-code') {
    final limit = key == 'dns.fallback-filter.geoip-code' ? 8 : 64;
    return value is String &&
        utf8.encode(value).length <= limit &&
        !_lineBreak.hasMatch(value) &&
        (key == 'dns.fallback-filter.geoip-code' || value.trim().isNotEmpty);
  }
  return null;
}

bool isIpingCidr(String value) {
  final parts = value.split('/');
  if (parts.length != 2 ||
      !RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(parts[1]) ||
      parts[0].contains('%')) {
    return false;
  }
  final ipv6 = parts[0].contains(':');
  if (!ipv6 &&
      parts[0]
          .split('.')
          .any((part) => !RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part))) {
    return false;
  }
  try {
    if (ipv6) {
      Uri.parseIPv6Address(parts[0]);
    } else {
      Uri.parseIPv4Address(parts[0]);
    }
    return int.parse(parts[1]) <= (ipv6 ? 128 : 32);
  } on FormatException {
    return false;
  }
}

bool isIpingListen(String value) {
  final colon = value.lastIndexOf(':');
  if (colon < 0 ||
      !RegExp(r'^[0-9]{1,5}$').hasMatch(value.substring(colon + 1))) {
    return false;
  }
  final port = int.parse(value.substring(colon + 1));
  if (port < 1 || port > 65535) return false;
  final host = value.substring(0, colon);
  if (host.isEmpty) return true;
  try {
    if (host.startsWith('[') && host.endsWith(']')) {
      Uri.parseIPv6Address(host.substring(1, host.length - 1));
    } else {
      return host.length <= 253 && host.split('.').every(_hostLabel.hasMatch);
    }
    return true;
  } on FormatException {
    return false;
  }
}

final _hostLabel = RegExp(r'^[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?$');
