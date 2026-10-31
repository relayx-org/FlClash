import 'package:fl_clash/common/num.dart';

import 'site_config.dart';

enum IpingTopupStatus { pending, success, cancelled }

String ipingCurrency(double value) => '¥${value.toStringAsFixed(2)}';

/// iPing reports tunnel traffic and plan allowances in GB, not bytes.
String ipingGigabytes(num value) => '${value.fixed()} GB';

double _roundBalance(double value) => (value * 100).roundToDouble() / 100;

double? _number(Object? value) => value is num && value.isFinite
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;

class IpingTopupOrder {
  const IpingTopupOrder({
    required this.id,
    required this.price,
    required this.bonus,
    required this.status,
    this.orderId = '',
    this.paymentName = '',
    this.payUrl,
    this.createdAt,
  });

  final int id;
  final double price;
  final double bonus;
  final IpingTopupStatus status;
  final String orderId;
  final String paymentName;
  final String? payUrl;
  final DateTime? createdAt;

  factory IpingTopupOrder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final price = _number(json['price']);
    final status = IpingTopupStatus.values.asNameMap()[json['status']];
    if (id is! int || price == null || status == null) {
      throw const FormatException('Invalid top-up order');
    }
    final payment = json['payment'];
    return IpingTopupOrder(
      id: id,
      price: price,
      bonus: _number(json['bonus']) ?? 0,
      status: status,
      orderId: json['order_id'] is String ? json['order_id'] as String : '',
      paymentName: payment is Map && payment['name'] is String
          ? payment['name'] as String
          : '',
      payUrl: json['pay_url'] is String ? json['pay_url'] as String : null,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class IpingTopupPage {
  const IpingTopupPage(this.orders, this.total);

  final List<IpingTopupOrder> orders;
  final int total;

  factory IpingTopupPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final total = json['total'];
    if (data is! List || total is! int) {
      throw const FormatException('Invalid top-up orders');
    }
    return IpingTopupPage([
      for (final item in data)
        IpingTopupOrder.fromJson(item as Map<String, dynamic>),
    ], total);
  }
}

class IpingPayment {
  const IpingPayment({
    required this.id,
    required this.name,
    this.icon = '',
    this.fixedFee = 0,
    this.percentFee = 0,
  });

  final int id;
  final String name;
  final String icon;
  final double fixedFee;

  /// A fraction of the price, as the backend stores it: 0.03 is 3%.
  final double percentFee;

  factory IpingPayment.fromJson(
    Map<String, dynamic> json, {
    required String site,
  }) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) {
      throw const FormatException('Invalid payment method');
    }
    return IpingPayment(
      id: id,
      name: name,
      icon: switch (json['icon']) {
        final String icon => ipingImageUrl(icon.trim(), site: site),
        _ => '',
      },
      fixedFee: _number(json['fixed_fee']) ?? 0,
      percentFee: _number(json['percent_fee']) ?? 0,
    );
  }
}

class IpingTopupActivity {
  const IpingTopupActivity({
    required this.percentage,
    required this.value,
    this.minAmount,
    this.maxAmount,
  });

  final bool percentage;
  final double value;
  final double? minAmount;
  final double? maxAmount;

  bool appliesTo(double price) =>
      (minAmount == null || minAmount! <= price) &&
      (maxAmount == null || maxAmount! >= price);

  factory IpingTopupActivity.fromJson(Map<String, dynamic> json) {
    final value = _number(json['value']);
    final type = json['type'];
    if (value == null || (type != 'percentage' && type != 'fixed')) {
      throw const FormatException('Invalid top-up activity');
    }
    return IpingTopupActivity(
      percentage: type == 'percentage',
      value: value,
      minAmount: _number(json['min_amount']),
      maxAmount: _number(json['max_amount']),
    );
  }
}

class IpingTopupOptions {
  const IpingTopupOptions({
    required this.payments,
    this.activities = const [],
    this.minAmount = 0,
  });

  final List<IpingPayment> payments;
  final List<IpingTopupActivity> activities;
  final double minAmount;

  /// Mirrors the backend's `calculateBonus`, which sums every activity whose
  /// range holds the price.
  double bonusFor(double price) => _roundBalance(
    activities
        .where((activity) => activity.appliesTo(price))
        .fold(
          0,
          (sum, activity) =>
              sum +
              (activity.percentage
                  ? price * activity.value / 100
                  : activity.value),
        ),
  );

  factory IpingTopupOptions.fromJson({
    required List<dynamic> payments,
    required List<dynamic> activities,
    required Object? minAmount,
    required String site,
  }) => IpingTopupOptions(
    payments: [
      for (final item in payments)
        IpingPayment.fromJson(item as Map<String, dynamic>, site: site),
    ],
    activities: [
      for (final item in activities)
        IpingTopupActivity.fromJson(item as Map<String, dynamic>),
    ],
    minAmount: _number(minAmount) ?? 0,
  );
}
