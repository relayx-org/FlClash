class IpingReferralStats {
  const IpingReferralStats({
    required this.userId,
    required this.link,
    required this.count,
    required this.earnings,
    required this.commissionRate,
  });

  final int userId;
  final String link;
  final int count;
  final double earnings;
  final double commissionRate;

  factory IpingReferralStats.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final count = json['referral_count'];
    final link = json['referral_link'];
    final uri = link is String ? Uri.tryParse(link) : null;
    final rate = _number(json['commission_rate']);
    if (userId is! int ||
        userId <= 0 ||
        count is! int ||
        count < 0 ||
        uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        !const ['https', 'http'].contains(uri.scheme) ||
        rate < 0 ||
        rate > 100) {
      throw const FormatException('Invalid referral information');
    }
    return IpingReferralStats(
      userId: userId,
      link: link as String,
      count: count,
      earnings: _number(json['total_earnings']),
      commissionRate: rate,
    );
  }
}

double _number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid account statistic');
  }
  return value.toDouble();
}
