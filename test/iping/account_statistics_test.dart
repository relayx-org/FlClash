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
}
