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

class IpingTrafficDay {
  const IpingTrafficDay({
    required this.date,
    required this.actual,
    required this.billed,
  });

  final DateTime date;
  final double actual;
  final double billed;
}

class IpingTrafficStats {
  const IpingTrafficStats(this.days);

  final List<IpingTrafficDay> days;

  double get actual => days.fold(0, (total, day) => total + day.actual);
  double get billed => days.fold(0, (total, day) => total + day.billed);

  factory IpingTrafficStats.fromJson(
    List<dynamic> json, {
    required DateTime start,
  }) {
    if (json.length > 64) throw const FormatException('Invalid traffic period');
    final totals = <DateTime, ({double actual, double billed})>{};
    for (final entry in json) {
      if (entry is! Map<String, dynamic> || entry['date'] is! String) {
        throw const FormatException('Invalid traffic information');
      }
      final date = DateTime.tryParse('${entry['date']}T00:00:00Z');
      final actual = _number(entry['traffic']);
      final billed = _number(entry['traffic_cost']);
      if (date == null ||
          date.toIso8601String().substring(0, 10) != entry['date'] ||
          actual < 0 ||
          billed < 0) {
        throw const FormatException('Invalid traffic information');
      }
      final previous = totals[date];
      totals[date] = (
        actual: _number((previous?.actual ?? 0) + actual),
        billed: _number((previous?.billed ?? 0) + billed),
      );
    }
    final days = List.generate(30, (i) {
      final date = start.add(Duration(days: i));
      final total = totals[date];
      return IpingTrafficDay(
        date: date,
        actual: total?.actual ?? 0,
        billed: total?.billed ?? 0,
      );
    });
    return IpingTrafficStats(List.unmodifiable(days));
  }
}

double _number(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid account statistic');
  }
  return value.toDouble();
}
