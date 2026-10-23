import 'package:fl_clash/iping/account_statistics.dart';
import 'package:fl_clash/iping/user_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Telegram binding and notification preferences follow the website response',
    () {
      final info = IpingUserInfo.fromJson({
        'id': 7,
        'email': 'user@example.com',
        'balance': 0,
        'tg_id': '12345',
        'notify_subscriptions': [
          'topup',
          'ip_expiring',
          'future-type',
          'topup',
        ],
      });
      expect(info.telegramBound, isTrue);
      expect(info.notificationSubscriptions, {
        'topup',
        'ip_expiring',
        'future-type',
      });
      expect(
        () => info.notificationSubscriptions!.add('changed'),
        throwsUnsupportedError,
      );
      final empty = IpingUserInfo.fromJson({
        'id': 7,
        'email': 'user@example.com',
        'balance': 0,
        'tg_id': null,
        'notify_subscriptions': [],
      });
      expect(empty.telegramBound, isFalse);
      expect(empty.notificationSubscriptions, isEmpty);
      final missing = IpingUserInfo.fromJson({
        'id': 7,
        'email': 'user@example.com',
        'balance': 0,
      });
      expect(missing.telegramBound, isNull);
      expect(missing.notificationSubscriptions, isNull);
    },
  );

  for (final invalid in <Map<String, dynamic>>[
    {'user_id': 0},
    {'referral_count': -1},
    {'commission_rate': 101},
    {'total_earnings': double.nan},
    {'referral_link': 'javascript:alert(1)'},
    {'referral_link': 'https://user:password@example.com'},
  ]) {
    test('invalid referral fields are rejected: $invalid', () {
      expect(
        () => IpingReferralStats.fromJson({
          'user_id': 7,
          'referral_link': 'https://example.com?ref=7',
          'referral_count': 0,
          'total_earnings': 0,
          'commission_rate': 0,
          ...invalid,
        }),
        throwsFormatException,
      );
    });
  }

  test(
    'traffic fills missing dates, merges today and ignores dates outside the window',
    () {
      final stats = IpingTrafficStats.fromJson([
        {'date': '2026-10-01', 'traffic': 2, 'traffic_cost': 3},
        {'date': '2026-10-30', 'traffic': 1.5, 'traffic_cost': 2},
        {'date': '2026-10-30', 'traffic': 4, 'traffic_cost': 6},
        {'date': '2026-09-30', 'traffic': 99, 'traffic_cost': 99},
      ], start: DateTime.utc(2026, 10, 1));
      expect(stats.days, hasLength(30));
      expect(stats.days[1].actual, 0);
      expect(stats.days.last.actual, 5.5);
      expect(stats.actual, 7.5);
      expect(stats.billed, 11);
      expect(() => stats.days.clear(), throwsUnsupportedError);
    },
  );

  test('an empty successful traffic response represents zero usage', () {
    final stats = IpingTrafficStats.fromJson(
      [],
      start: DateTime.utc(2026, 10, 1),
    );
    expect(stats.actual, 0);
    expect(stats.billed, 0);
    expect(stats.days, hasLength(30));
  });

  for (final invalid in [
    {'date': '2026-02-31', 'traffic': 1, 'traffic_cost': 1},
    {'date': '2026-10-01', 'traffic': -1, 'traffic_cost': 1},
    {'date': '2026-10-01', 'traffic': 1, 'traffic_cost': double.infinity},
    {'date': '2026-10-01', 'traffic': 1},
  ]) {
    test('malformed traffic never becomes a fabricated zero: $invalid', () {
      expect(
        () => IpingTrafficStats.fromJson([
          invalid,
        ], start: DateTime.utc(2026, 10, 1)),
        throwsFormatException,
      );
    });
  }
}
