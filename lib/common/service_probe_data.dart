import 'dart:convert';
import '../models/ip_info.dart';
export '../models/ip_info.dart';

import 'package:flutter/foundation.dart';

/// [id] matches the checker names in the shared Go probe package.
enum ServiceTarget {
  google('google', 'Google', 'google'),
  github('github', 'GitHub', 'github'),
  youtube('youtube', 'YouTube', 'youtube'),
  chatgpt('chatgpt', 'ChatGPT', 'openai'),
  claude('claude', 'Claude', 'claude'),
  gemini('gemini', 'Gemini', 'gemini'),
  netflix('netflix', 'Netflix', 'netflix'),
  disneyPlus('disney-plus', 'Disney+', 'disneyplus'),
  primeVideo('prime-video', 'Prime Video', 'primevideo'),
  spotify('spotify', 'Spotify', 'spotify'),
  tiktok('tiktok', 'TikTok', 'tiktok'),
  discord('discord', 'Discord', 'discord'),
  bilibili('bilibili', 'bilibili', 'bilibili');

  const ServiceTarget(this.id, this.label, this.icon);

  final String id;
  final String label;
  final String icon;

  static ServiceTarget? byId(String id) {
    for (final target in values) {
      if (target.id == id) return target;
    }
    return null;
  }
}

enum ServiceProbeStatus {
  available('available'),
  unavailable('unavailable'),
  restricted('restricted'),
  disallowedIsp('disallowed-isp'),
  blocked('blocked'),
  unsupportedRegion('unsupported-region'),
  originalsOnly('originals-only'),
  comingSoon('coming-soon'),
  timeout('timeout'),
  failed('failed');

  const ServiceProbeStatus(this.id);

  final String id;

  static ServiceProbeStatus byId(String id) {
    for (final status in values) {
      if (status.id == id) return status;
    }
    return ServiceProbeStatus.failed;
  }
}

List<ServiceTarget> orderServiceTargets(List<String> order) {
  return {
    for (final id in order) ?ServiceTarget.byId(id),
    ...ServiceTarget.values,
  }.toList();
}

List<ServiceTarget> enabledServices(
  List<ServiceTarget> targets,
  List<String> disabled,
) {
  final hidden = disabled.toSet();
  final enabled = [
    for (final target in targets)
      if (!hidden.contains(target.id)) target,
  ];
  return enabled.isEmpty ? targets : enabled;
}

class ServiceCheck {
  const ServiceCheck(
    this.status, {
    this.delay,
    this.chains = const [],
    this.region,
    this.checkedAt,
    this.coreEpoch = 0,
    this.picksVersion = 0,
  });

  factory ServiceCheck.fromJson(Map<String, dynamic> data) {
    final delay = (data['delay'] as num?)?.toInt() ?? 0;
    final checked = (data['checked-at'] as num?)?.toInt() ?? 0;
    final region = data['region'] as String? ?? '';
    return ServiceCheck(
      ServiceProbeStatus.byId(data['status'] as String? ?? ''),
      delay: delay > 0 ? delay : null,
      chains: (data['chains'] as List?)?.cast<String>() ?? const [],
      region: region.isEmpty ? null : region,
      checkedAt: checked > 0
          ? DateTime.fromMillisecondsSinceEpoch(checked)
          : null,
      coreEpoch: (data['core-epoch'] as num?)?.toInt() ?? 0,
      picksVersion: (data['picks-version'] as num?)?.toInt() ?? 0,
    );
  }

  final ServiceProbeStatus status;
  final int? delay;
  final List<String> chains;
  final String? region;
  final DateTime? checkedAt;
  final int coreEpoch;
  final int picksVersion;

  String? get node => chains.firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is ServiceCheck &&
      other.status == status &&
      other.delay == delay &&
      listEquals(other.chains, chains) &&
      other.region == region &&
      other.checkedAt == checkedAt &&
      other.coreEpoch == coreEpoch &&
      other.picksVersion == picksVersion;

  @override
  int get hashCode => Object.hash(
    status,
    delay,
    Object.hashAll(chains),
    region,
    checkedAt,
    coreEpoch,
    picksVersion,
  );

  @override
  String toString() =>
      'ServiceCheck(${status.id}, delay: $delay, node: $node, region: $region)';
}

IpInfo Function(String) _json(IpInfo Function(Map<String, dynamic>) parse) {
  return (body) => parse(jsonDecode(body) as Map<String, dynamic>);
}

final Map<String, IpInfo Function(String)> ipInfoSources = {
  'https://www.cloudflare.com/cdn-cgi/trace': IpInfo.fromCloudflareTrace,
  'https://api.ip.sb/geoip': _json(IpInfo.fromIpSbJson),
  'https://ipinfo.io/json': _json(IpInfo.fromIpInfoIoJson),
  'https://ipwho.is': _json(IpInfo.fromIpWhoIsJson),
  'http://ip-api.com/json': _json(IpInfo.fromIpAPIJson),
  'https://get.geojs.io/v1/ip/geo.json': _json(IpInfo.fromGeoJsJson),
  'https://api.country.is': _json(IpInfo.fromCountryIsJson),
  'https://api.ipquery.io/?format=json': _json(IpInfo.fromIpQueryJson),
  'https://ident.me/json': _json(IpInfo.fromIdentMeJson),
};

IpInfo? parseOutboundIpBody({String? url, String? body, String? error}) {
  if (error != null || body == null || body.isEmpty) return null;
  final parse = ipInfoSources[url];
  if (parse == null) return null;
  try {
    return parse(body);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
