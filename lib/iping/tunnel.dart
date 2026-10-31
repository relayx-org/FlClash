import 'api.dart';

/// One page of the signed-in user's tunnels.
class IpingTunnelQuery {
  const IpingTunnelQuery({
    this.name = '',
    this.status,
    this.expired,
    this.tunnelType,
    this.autoRenew,
    this.listenPort,
    this.ipType,
    this.id,
    this.page = 1,
    this.perPage = 100,
  });

  /// Server matches this as a substring of the tunnel name.
  final String name;

  /// `active` or `inactive`. The store has no expired status.
  final String? status;

  /// `true` keeps expired tunnels, `false` keeps current ones.
  final bool? expired;
  final String? tunnelType;
  final bool? autoRenew;
  final int? listenPort;
  final String? ipType;
  final int? id;
  final int page;
  final int perPage;

  IpingTunnelQuery copyWith({
    int? page,
    String? name,
    String? status,
    bool? expired,
    String? tunnelType,
    bool? autoRenew,
    int? listenPort,
    String? ipType,
    int? id,
  }) => IpingTunnelQuery(
    name: name ?? this.name,
    status: status ?? this.status,
    expired: expired ?? this.expired,
    tunnelType: tunnelType ?? this.tunnelType,
    autoRenew: autoRenew ?? this.autoRenew,
    listenPort: listenPort ?? this.listenPort,
    ipType: ipType ?? this.ipType,
    id: id ?? this.id,
    page: page ?? this.page,
    perPage: perPage,
  );

  Map<String, dynamic> toParameters() {
    final trimmed = name.trim();
    return {
      'page': page,
      'perPage': perPage,
      if (trimmed.isNotEmpty) 'name': trimmed,
      if (status != null) 'status': status,
      if (expired != null) 'is_expired': expired! ? 'true' : 'false',
      if (tunnelType != null && tunnelType!.isNotEmpty)
        'tunnel_type': tunnelType,
      if (autoRenew != null) 'auto_renew': autoRenew! ? 'true' : 'false',
      if (listenPort != null) 'listen_port': listenPort,
      if (ipType != null && ipType!.isNotEmpty) 'ip_type': ipType,
      if (id != null) 'id': id,
    };
  }
}

class IpingTunnelPage {
  const IpingTunnelPage({required this.items, required this.total});

  final List<IpingTunnel> items;
  final int total;

  bool get hasMore => items.length < total;

  IpingTunnelPage append(IpingTunnelPage next) =>
      IpingTunnelPage(items: [...items, ...next.items], total: next.total);

  factory IpingTunnelPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final total = json['total'];
    if (data is! List || total is! num) {
      throw const FormatException('Missing tunnels');
    }
    return IpingTunnelPage(
      total: total.toInt(),
      items: [
        for (final item in data)
          if (item is Map)
            ?IpingTunnel.tryParse(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class IpingTunnelEndpoint {
  const IpingTunnelEndpoint({
    required this.name,
    this.trafficRate = 1,
    this.connectIp,
    this.nodeAddresses = const [],
  });

  final String name;
  final num trafficRate;
  final String? connectIp;
  final List<String> nodeAddresses;

  static IpingTunnelEndpoint? tryParse(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final rate = json['traffic_rate'];
    final nodes = json['nodes'];
    return IpingTunnelEndpoint(
      name: name,
      trafficRate: rate is num ? rate : 1,
      connectIp: json['connect_ip'] is String
          ? json['connect_ip'] as String
          : null,
      nodeAddresses: nodes is List
          ? [
              for (final node in nodes)
                if (node is Map && node['connect_ip'] is String)
                  node['connect_ip'] as String,
            ]
          : const [],
    );
  }
}

class ParsedProxyAddress {
  const ParsedProxyAddress({
    this.protocol = 'socks5',
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
  });

  final String protocol;
  final String host;
  final int port;
  final String username;
  final String password;
}

List<ParsedProxyAddress> parseProxyAddresses(String text) {
  final addresses = <ParsedProxyAddress>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final url = RegExp(
      r'^(socks5|http|ss)://(?:([^:]*):([^@]*)@)?(\[[^\]]+\]|[^:\s]+):(\d+)$',
      caseSensitive: false,
    ).firstMatch(line);
    final fields = url == null
        ? RegExp(r'^(\[[^\]]+\]|[^:\s]+):(\d+):([^:]*):(.*)$').firstMatch(line)
        : null;
    final auth = url == null && fields == null
        ? RegExp(
            r'^([^:]+):([^@]+)@(\[[^\]]+\]|[^:\s]+):(\d+)$',
          ).firstMatch(line)
        : null;
    final plain = url == null && fields == null && auth == null
        ? RegExp(r'^(\[[^\]]+\]|[^:\s]+):(\d+)$').firstMatch(line)
        : null;

    ParsedProxyAddress? parsed;
    if (url != null) {
      parsed = ParsedProxyAddress(
        protocol: (url.group(1) ?? 'socks5').toLowerCase(),
        username: Uri.decodeComponent(url.group(2) ?? ''),
        password: Uri.decodeComponent(url.group(3) ?? ''),
        host: url.group(4) ?? '',
        port: int.tryParse(url.group(5) ?? '') ?? 0,
      );
    } else if (fields != null) {
      parsed = ParsedProxyAddress(
        host: fields.group(1) ?? '',
        port: int.tryParse(fields.group(2) ?? '') ?? 0,
        username: fields.group(3) ?? '',
        password: fields.group(4) ?? '',
      );
    } else if (auth != null) {
      parsed = ParsedProxyAddress(
        username: auth.group(1) ?? '',
        password: auth.group(2) ?? '',
        host: auth.group(3) ?? '',
        port: int.tryParse(auth.group(4) ?? '') ?? 0,
      );
    } else if (plain != null) {
      parsed = ParsedProxyAddress(
        host: plain.group(1) ?? '',
        port: int.tryParse(plain.group(2) ?? '') ?? 0,
      );
    }
    if (parsed != null && parsed.port >= 1 && parsed.port <= 65535) {
      addresses.add(parsed);
    }
  }
  return addresses;
}

class IpingUserProxy {
  const IpingUserProxy({
    required this.id,
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
    this.country,
    this.city,
    this.remarks,
    this.type = 'socks5',
    this.expiredAt,
    this.price = 0,
    this.autoRenew = false,
    this.inTunnel = false,
  });

  final int id;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? country;
  final String? city;
  final String? remarks;
  final String type;
  final DateTime? expiredAt;
  final num price;
  final bool autoRenew;
  final bool inTunnel;

  bool get isExpired {
    final expiry = expiredAt;
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  String get endpoint => '$host:$port';

  String get credentials =>
      username.isEmpty ? endpoint : '$username:$password@$endpoint';

  static IpingUserProxy? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final host = json['host'];
    final port = json['port'];
    if (id is! num || host is! String || port is! num) return null;
    return IpingUserProxy(
      id: id.toInt(),
      host: host,
      port: port.toInt(),
      username: json['username'] is String ? json['username'] as String : '',
      password: json['password'] is String ? json['password'] as String : '',
      country: json['country'] is String ? json['country'] as String : null,
      city: json['city'] is String ? json['city'] as String : null,
      remarks: json['remarks'] is String ? json['remarks'] as String : null,
      type: json['type'] is String ? json['type'] as String : 'socks5',
      expiredAt: _date(json['expired_at']),
      price: json['price'] is num ? json['price'] as num : 0,
      autoRenew: json['auto_renew'] == true,
      inTunnel: json['in_tunnel'] == true,
    );
  }
}

class IpingTunnel {
  const IpingTunnel({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.listenPort,
    this.portConflictAt,
    this.expiredAt,
    this.autoRenew = false,
    this.traffic = 0,
    this.trafficCost = 0,
    this.totalTraffic = 0,
    this.entrance,
    this.exit,
    this.forwardAddresses = const {},
    this.forwardUsername,
    this.forwardPassword,
    this.canChangeForwardAddress = true,
    this.planName,
    this.planPrice,
    this.poolExit = false,
    this.poolCountry,
    this.poolIntervalMinutes,
    this.ipType,
    this.listenProtocol,
    this.listenUsername,
    this.listenPassword,
  });

  final int id;
  final String name;
  final String type;
  final String status;
  final int? listenPort;
  final DateTime? portConflictAt;
  final DateTime? expiredAt;
  final bool autoRenew;
  final num traffic;

  /// Traffic after the node rates; the allowance in [totalTraffic] counts this.
  final num trafficCost;
  final num totalTraffic;
  final IpingTunnelEndpoint? entrance;
  final IpingTunnelEndpoint? exit;
  final Map<String, num> forwardAddresses;
  final String? forwardUsername;
  final String? forwardPassword;
  final bool canChangeForwardAddress;
  final String? planName;
  final num? planPrice;
  final bool poolExit;
  final String? poolCountry;
  final int? poolIntervalMinutes;
  final String? ipType;
  final String? listenProtocol;
  final String? listenUsername;
  final String? listenPassword;

  bool get enabled => status == 'active';

  bool get isExpired {
    final expiry = expiredAt;
    return expiry != null && !expiry.isAfter(DateTime.now());
  }

  bool get portInUse {
    final conflict = portConflictAt;
    if (conflict == null) return false;
    final age = DateTime.now().difference(conflict);
    return !age.isNegative && age < const Duration(seconds: 60);
  }

  /// Same address lines as the store: group `connect_ip` wins, otherwise each
  /// node's address, with IPv6 wrapped in brackets. A missing port reads WAIT.
  List<String> get listenAddresses {
    final group = entrance;
    if (group == null) return const [];
    final port = listenPort?.toString() ?? 'WAIT';
    final ips = <String>[];
    final connect = group.connectIp?.trim();
    if (connect == null || connect.isEmpty) {
      for (final raw in group.nodeAddresses) {
        for (final part in raw.split(',')) {
          final ip = part.trim();
          if (ip.isEmpty) continue;
          ips.add(ip.contains(':') ? '[$ip]' : ip);
        }
      }
    } else {
      for (final part in connect.split(',')) {
        final ip = part.trim();
        if (ip.isEmpty) continue;
        ips.add(ip);
      }
    }
    return [for (final ip in ips) '$ip:$port'];
  }

  IpingTunnel copyWith({
    String? name,
    String? status,
    bool? autoRenew,
    int? listenPort,
    Map<String, num>? forwardAddresses,
    String? forwardUsername,
    String? forwardPassword,
    bool? canChangeForwardAddress,
    String? poolCountry,
    int? poolIntervalMinutes,
    String? ipType,
  }) => IpingTunnel(
    id: id,
    name: name ?? this.name,
    type: type,
    status: status ?? this.status,
    listenPort: listenPort ?? this.listenPort,
    portConflictAt: portConflictAt,
    expiredAt: expiredAt,
    autoRenew: autoRenew ?? this.autoRenew,
    traffic: traffic,
    trafficCost: trafficCost,
    totalTraffic: totalTraffic,
    entrance: entrance,
    exit: exit,
    forwardAddresses: forwardAddresses ?? this.forwardAddresses,
    forwardUsername: forwardUsername ?? this.forwardUsername,
    forwardPassword: forwardPassword ?? this.forwardPassword,
    canChangeForwardAddress:
        canChangeForwardAddress ?? this.canChangeForwardAddress,
    planName: planName,
    planPrice: planPrice,
    poolExit: poolExit,
    poolCountry: poolCountry ?? this.poolCountry,
    poolIntervalMinutes: poolIntervalMinutes ?? this.poolIntervalMinutes,
    ipType: ipType ?? this.ipType,
    listenProtocol: listenProtocol,
    listenUsername: listenUsername,
    listenPassword: listenPassword,
  );

  static IpingTunnel? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num || id <= 0) return null;
    final name = json['name'];
    final type = json['tunnel_type'];
    final status = json['status'];
    final price = json['tunnel_price'];
    final plan = price is Map ? Map<String, dynamic>.from(price) : null;
    final planName = plan?['name'];
    final planPrice = plan?['price'];
    final pool = json['sk5_pool_mode'];
    final protocol = json['forward_addresses_protocol'] is Map
        ? Map<String, dynamic>.from(json['forward_addresses_protocol'] as Map)
        : null;
    final listen = json['listen_protocol'] is Map
        ? Map<String, dynamic>.from(json['listen_protocol'] as Map)
        : null;
    return IpingTunnel(
      id: id.toInt(),
      name: name is String ? name : '',
      type: type is String && type.isNotEmpty ? type : 'tcp',
      status: status == 'inactive' ? 'inactive' : 'active',
      listenPort: json['listen_port'] is num
          ? (json['listen_port'] as num).toInt()
          : null,
      portConflictAt: _date(json['port_conflict_at']),
      expiredAt: _date(json['expired_at']),
      autoRenew: json['auto_renew'] == true,
      traffic: json['traffic'] is num ? json['traffic'] as num : 0,
      trafficCost: json['traffic_cost'] is num
          ? json['traffic_cost'] as num
          : 0,
      totalTraffic: json['total_traffic'] is num
          ? json['total_traffic'] as num
          : 0,
      entrance: IpingTunnelEndpoint.tryParse(json['in_node_group']),
      exit: IpingTunnelEndpoint.tryParse(json['out_node_group']),
      forwardAddresses: _weights(json['forward_addresses']),
      forwardUsername: protocol?['username'] is String
          ? protocol!['username'] as String
          : null,
      forwardPassword: protocol?['password'] is String
          ? protocol!['password'] as String
          : null,
      canChangeForwardAddress: json['can_change_forward_address'] != false,
      planName: planName is String && planName.isNotEmpty ? planName : null,
      planPrice: planPrice is num ? planPrice : null,
      poolExit: pool is String && pool.isNotEmpty,
      poolCountry: json['sk5_pool_country'] is String
          ? json['sk5_pool_country'] as String
          : null,
      poolIntervalMinutes: json['sk5_pool_interval_minutes'] is num
          ? (json['sk5_pool_interval_minutes'] as num).toInt()
          : null,
      ipType: json['ip_type'] is String ? json['ip_type'] as String : null,
      listenProtocol: _text(listen?['type']),
      listenUsername: _text(listen?['username']),
      listenPassword: _text(listen?['password']),
    );
  }
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Map<String, num> _weights(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String &&
          (entry.key as String).isNotEmpty &&
          entry.value is num)
        entry.key as String: entry.value as num,
  };
}

extension TunnelApi on IpingApi {
  /// The user route hides tunnels that have been expired for more than three days.
  Future<IpingTunnelPage> tunnels(IpingTunnelQuery query) async {
    final json = await get<Map<String, dynamic>>(
      'tunnel',
      queryParameters: query.toParameters(),
    );
    try {
      return IpingTunnelPage.fromJson(json);
    } on FormatException {
      throw const IpingException(IpingFailure.unavailable);
    } on TypeError {
      throw const IpingException(IpingFailure.unavailable);
    }
  }

  Future<IpingTunnel?> tunnel(int id) async {
    final page = await tunnels(IpingTunnelQuery(id: id, perPage: 1));
    for (final item in page.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<List<IpingUserProxy>> userProxies({
    int page = 1,
    int perPage = 100,
  }) async {
    final json = await get<Map<String, dynamic>>(
      'ipproxy',
      queryParameters: {'page': page, 'perPage': perPage},
    );
    final data = json['data'];
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map)
          ?IpingUserProxy.tryParse(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> renewTunnel(int id) => postVoid('tunnel/$id/renew');

  Future<void> batchRenewTunnels(List<int> ids) =>
      postVoid('tunnel/batch/renew', data: {'ids': ids});

  Future<void> switchIp(int id) => postVoid('tunnel/$id/switch-ip');

  Future<void> updatePoolSettings(
    int id, {
    String? name,
    int? intervalMinutes,
    String? country,
  }) {
    return patchVoid(
      'sk5-pool/$id',
      data: {
        'interval_minutes': ?intervalMinutes,
        'country': ?country,
        'name': ?name,
      },
    );
  }

  Future<void> updateTunnel(int id, {String? status, bool? autoRenew}) {
    return patchVoid(
      'tunnel/batch/update',
      data: {
        'ids': [id],
        'status': ?status,
        'auto_renew': ?autoRenew,
      },
    );
  }

  Future<void> batchUpdateTunnels({
    required List<int> ids,
    String? status,
    bool? autoRenew,
  }) => patchVoid(
    'tunnel/batch/update',
    data: {'ids': ids, 'status': ?status, 'auto_renew': ?autoRenew},
  );

  Future<void> batchFillTunnels(List<Map<String, dynamic>> items) =>
      patchVoid('tunnel/batch/fill', data: {'items': items});

  Future<void> fillTunnel(
    int id, {
    String? name,
    Map<String, num>? forwardAddresses,
    String? forwardUsername,
    String? forwardPassword,
  }) {
    final hasProtocol =
        (forwardUsername != null && forwardUsername.isNotEmpty) ||
        (forwardPassword != null && forwardPassword.isNotEmpty);
    return patchVoid(
      'tunnel/batch/fill',
      data: {
        'items': [
          {
            'id': id,
            'name': ?name,
            'forward_addresses': ?forwardAddresses,
            if (forwardAddresses != null)
              'forward_addresses_protocol': hasProtocol
                  ? {
                      'type': 'socks5',
                      'username': forwardUsername,
                      'password': forwardPassword,
                    }
                  : null,
          },
        ],
      },
    );
  }

  Future<int> switchPort(int id) async {
    final res = await post<Map<String, dynamic>>('tunnel/$id/switch-port');
    final port = res['listen_port'];
    if (port is num) return port.toInt();
    throw const IpingException(IpingFailure.unavailable);
  }

  Future<void> saveTunnel({
    required int id,
    String? name,
    Map<String, num>? forwardAddresses,
    String? forwardUsername,
    String? forwardPassword,
    String? status,
    bool? autoRenew,
  }) async {
    final futures = <Future<void>>[];
    if (name != null || forwardAddresses != null) {
      futures.add(
        fillTunnel(
          id,
          name: name,
          forwardAddresses: forwardAddresses,
          forwardUsername: forwardUsername,
          forwardPassword: forwardPassword,
        ),
      );
    }
    if (status != null || autoRenew != null) {
      futures.add(updateTunnel(id, status: status, autoRenew: autoRenew));
    }
    await Future.wait(futures);
  }
}
