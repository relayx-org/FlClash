import '../enum/enum.dart';
import '../models/models.dart';
import 'backend_settings.dart';

Map<String, Object?> _dnsJson(Dns dns) => {
  ...dns.toJson(),
  'fallback-filter': dns.fallbackFilter.toJson(),
};

Object? _at(Map<String, Object?> values, String path) {
  Object? value = values;
  for (final part in path.split('.')) {
    value = (value! as Map)[part];
  }
  return value;
}

IpingSettings nativeIpingSettings(
  PatchClashConfig config, {
  required bool desktop,
}) {
  final patch = config.toJson();
  final dns = _dnsJson(config.dns);
  final tun = desktop ? config.tunOverride.toJson() : config.tun.toJson();
  return IpingSettings(
    {
      for (final key in IpingSettings.generalKeys) key: patch[key],
      for (final key in DnsOverrideKey.values)
        'dns.${key.path}': _at(dns, key.path),
      for (final entry in config.tun.toJson().entries)
        if (const {'enable', 'device', 'stack'}.contains(entry.key))
          'tun.${entry.key}': entry.value,
      for (final entry in tun.entries) 'tun.${entry.key}': entry.value,
    },
    choices: {
      'find-process-mode': FindProcessMode.values
          .map((value) => value.name)
          .toList(),
      'tun.stack': TunStack.values.map((value) => value.name).toList(),
    },
    overrides: {
      for (final key in DnsOverrideKey.values)
        'dns.${key.path}': config.dnsOverrideKeys.contains(key),
      if (desktop)
        for (final key in TunOverrideKey.values)
          'tun.${key.path}': config.tunOverrideKeys.contains(key),
    },
    collectionLimit: null,
  );
}

Map<String, Object?> _patched(
  Map<String, Object?> values,
  Map<String, Object?> defaults,
  Map<String, Object?> changes,
  String section,
) {
  for (final entry in changes.entries) {
    if (!entry.key.startsWith('$section.')) continue;
    final path = entry.key.substring(section.length + 1);
    final parts = path.split('.');
    var parent = values;
    for (final part in parts.take(parts.length - 1)) {
      parent = parent[part]! as Map<String, Object?>;
    }
    parent[parts.last] = entry.value ?? _at(defaults, path);
  }
  return values;
}

PatchClashConfig applyNativeIpingSettings(
  PatchClashConfig state,
  Map<String, Object?> changes, {
  required bool desktop,
}) {
  nativeIpingSettings(state, desktop: desktop).validate(changes);
  final dnsKeys = {...state.dnsOverrideKeys};
  final tunKeys = {...state.tunOverrideKeys};
  for (final key in DnsOverrideKey.values) {
    if (!changes.containsKey('dns.${key.path}')) continue;
    if (changes['dns.${key.path}'] == null) {
      dnsKeys.remove(key);
    } else {
      dnsKeys.add(key);
    }
  }
  if (desktop) {
    for (final key in TunOverrideKey.values) {
      if (!changes.containsKey('tun.${key.path}')) continue;
      if (changes['tun.${key.path}'] == null) {
        tunKeys.remove(key);
      } else {
        tunKeys.add(key);
      }
    }
  }
  final dnsChanged = changes.keys.any((key) => key.startsWith('dns.'));
  final tunChanged = changes.keys.any((key) => key.startsWith('tun.'));
  final coreTunChanges = desktop
      ? {
          for (final key in ['tun.enable', 'tun.device', 'tun.stack'])
            if (changes.containsKey(key)) key: changes[key],
        }
      : changes;
  final ua = changes['global-ua'] as String?;
  return state.copyWith(
    dns: dnsChanged
        ? Dns.fromJson(
            _patched(_dnsJson(state.dns), _dnsJson(defaultDns), changes, 'dns'),
          )
        : state.dns,
    dnsOverrideKeys: dnsKeys,
    tunOverride: desktop && tunChanged
        ? ProfileTun.fromJson(
            _patched(state.tunOverride.toJson(), defaultProfileTun.toJson(), {
              for (final key in TunOverrideKey.values)
                if (changes.containsKey('tun.${key.path}'))
                  'tun.${key.path}': changes['tun.${key.path}'],
            }, 'tun'),
          )
        : state.tunOverride,
    tunOverrideKeys: tunKeys,
    tun: coreTunChanges.keys.any((key) => key.startsWith('tun.'))
        ? Tun.fromJson(
            _patched(
              state.tun.toJson(),
              defaultTun.toJson(),
              coreTunChanges,
              'tun',
            ),
          )
        : state.tun,
    disableKeepAlive:
        changes['disable-keep-alive'] as bool? ?? state.disableKeepAlive,
    keepAliveIdle: changes['keep-alive-idle'] as int? ?? state.keepAliveIdle,
    keepAliveInterval:
        changes['keep-alive-interval'] as int? ?? state.keepAliveInterval,
    routingMark: changes['routing-mark'] as int? ?? state.routingMark,
    mixedPort: changes['mixed-port'] as int? ?? state.mixedPort,
    port: changes['port'] as int? ?? state.port,
    socksPort: changes['socks-port'] as int? ?? state.socksPort,
    redirPort: changes['redir-port'] as int? ?? state.redirPort,
    tproxyPort: changes['tproxy-port'] as int? ?? state.tproxyPort,
    allowLan: changes['allow-lan'] as bool? ?? state.allowLan,
    ipv6: changes['ipv6'] as bool? ?? state.ipv6,
    unifiedDelay: changes['unified-delay'] as bool? ?? state.unifiedDelay,
    tcpConcurrent: changes['tcp-concurrent'] as bool? ?? state.tcpConcurrent,
    logLevel: changes.containsKey('log-level')
        ? LogLevel.values.byName(changes['log-level']! as String)
        : state.logLevel,
    findProcessMode: changes.containsKey('find-process-mode')
        ? FindProcessMode.values.byName(changes['find-process-mode']! as String)
        : state.findProcessMode,
    geodataLoader: changes.containsKey('geodata-loader')
        ? GeodataLoader.values.byName(changes['geodata-loader']! as String)
        : state.geodataLoader,
    globalUa: changes.containsKey('global-ua')
        ? ua == null || ua.isEmpty
              ? null
              : ua
        : state.globalUa,
    hosts: changes.containsKey('hosts')
        ? Map<String, String>.from(changes['hosts']! as Map)
        : state.hosts,
  );
}
