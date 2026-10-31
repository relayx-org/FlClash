import 'api.dart';

/// A line of native residential IP the store sells.
enum NativeIpLine {
  a('native'),
  b('native2'),
  c('native3');

  const NativeIpLine(this.ipType);

  /// The path segment the buy route expects.
  final String ipType;
}

class NativeIpTag {
  const NativeIpTag({required this.key, required this.label, this.tone});

  /// Stable filter id. Falls back to [label] when the payload omits a key.
  final String key;
  final String label;

  /// Visual tone from the store, such as `residential` or `live`.
  final String? tone;
}

class NativeIpOffer {
  const NativeIpOffer({
    required this.line,
    required this.countryCode,
    required this.country,
    required this.cityName,
    required this.city,
    required this.stock,
    required this.price,
    required this.tags,
  });

  final NativeIpLine line;
  final String countryCode;
  final String country;
  final String cityName;
  final String city;
  final int stock;

  /// Monthly list price in CNY. The backend applies any reseller discount.
  final double price;
  final List<NativeIpTag> tags;

  String get place {
    final hasCountry =
        country.isNotEmpty &&
        country.toLowerCase() != countryCode.toLowerCase();
    final parts = [if (hasCountry) country, if (cityName.isNotEmpty) cityName];
    if (parts.isNotEmpty) return parts.join(' · ');
    return country.isNotEmpty ? country : countryCode.toUpperCase();
  }

  factory NativeIpOffer.fromJson(Map<String, dynamic> json, NativeIpLine line) {
    final tags = json['tags'];
    return NativeIpOffer(
      line: line,
      countryCode: json['country_code'] as String,
      country: (json['country'] as String?)?.trim() ?? '',
      cityName: (json['city_name'] as String?)?.trim() ?? '',
      city: (json['city'] as String?)?.trim() ?? '',
      stock: (json['number'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      tags: _nativeIpTags(tags),
    );
  }
}

List<NativeIpTag> _nativeIpTags(Object? value) {
  if (value is! List) return const [];
  final tags = <NativeIpTag>[];
  for (final item in value) {
    if (item is! Map) continue;
    final tag = _nativeIpTag(item);
    if (tag != null) tags.add(tag);
  }
  return tags;
}

NativeIpTag? _nativeIpTag(Map<dynamic, dynamic> json) {
  final label = json['label'];
  if (label is! String || label.trim().isEmpty) return null;
  final trimmed = label.trim();
  final rawKey = json['key'];
  final key = rawKey is String && rawKey.trim().isNotEmpty
      ? rawKey.trim()
      : trimmed;
  final rawTone = json['tone'];
  final tone = rawTone is String && rawTone.trim().isNotEmpty
      ? rawTone.trim()
      : null;
  return NativeIpTag(key: key, label: trimmed, tone: tone);
}

class TunnelPlan {
  const TunnelPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.traffic,
    required this.type,
    this.description,
  });

  final int id;
  final String name;
  final double price;

  /// Included traffic in GB.
  final num traffic;
  final String type;
  final String? description;

  bool get isTrial => type == 'trial';

  factory TunnelPlan.fromJson(Map<String, dynamic> json) => TunnelPlan(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    traffic: json['traffic'] as num,
    type: json['type'] as String,
    description: (json['description'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['description'] as String).trim(),
  );
}

class NativeIpPurchase {
  const NativeIpPurchase({
    required this.offer,
    required this.months,
    required this.count,
    this.tunnelPlanId,
  });

  final NativeIpOffer offer;
  final int months;
  final int count;

  /// Set when a tunnel is bought for every IP.
  final int? tunnelPlanId;

  int get days => months * 30;
}

class NativeIpOrder {
  const NativeIpOrder({
    this.orderNo,
    this.ids = const [],
    this.tunnelIds = const [],
  });

  final String? orderNo;
  final List<int> ids;

  /// Tunnels created with the IPs. Empty when none were bought.
  final List<int> tunnelIds;

  bool get delivered => ids.isNotEmpty;

  factory NativeIpOrder.fromJson(Map<String, dynamic> json) {
    List<int> numbers(Object? value) => value is List
        ? [
            for (final item in value)
              if (item is num) item.toInt(),
          ]
        : const [];
    final orderNo = json['order_no'];
    return NativeIpOrder(
      orderNo: orderNo is String && orderNo.isNotEmpty ? orderNo : null,
      ids: numbers(json['ids']),
      tunnelIds: numbers(json['tunnel_ids']),
    );
  }
}

extension NativeIpApi on IpingApi {
  Future<List<NativeIpOffer>> nativeIpInventory() async {
    final lines = await Future.wait([
      for (final line in NativeIpLine.values)
        get<List<dynamic>>('ipproxy/inventory/${line.ipType}').then(
          (items) => <NativeIpOffer>[
            for (final item in items)
              if (item is Map)
                NativeIpOffer.fromJson(Map<String, dynamic>.from(item), line),
          ],
        ),
    ]);
    final offers = [for (final line in lines) ...line]
      ..sort((a, b) {
        final byCountry = a.country.compareTo(b.country);
        return byCountry != 0 ? byCountry : a.cityName.compareTo(b.cityName);
      });
    return offers;
  }

  Future<List<TunnelPlan>> tunnelPlans() async {
    final prices = await get<List<dynamic>>('tunnel/prices');
    return [
      for (final price in prices)
        if (price is Map) TunnelPlan.fromJson(Map<String, dynamic>.from(price)),
    ].where((plan) => !plan.isTrial).toList();
  }

  Future<NativeIpOrder> buyNativeIp(NativeIpPurchase purchase) async {
    final offer = purchase.offer;
    final order = await post<Map<String, dynamic>>(
      'ipproxy/buy/${offer.line.ipType}',
      data: {
        'day': purchase.days,
        'country_code': offer.countryCode,
        'country': offer.country,
        'city': offer.city,
        'count': purchase.count,
        'bandwidth': 0,
        'router_buy': false,
        'tunnel_price_id': ?purchase.tunnelPlanId,
      },
    );
    return NativeIpOrder.fromJson(order);
  }
}
