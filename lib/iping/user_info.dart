class IpingUserInfo {
  const IpingUserInfo({
    required this.id,
    required this.email,
    required this.balance,
    required this.status,
    this.createdAt,
    this.telegramBound,
    this.notificationSubscriptions,
  });

  final int id;
  final String email;
  final double balance;
  final String status;
  final DateTime? createdAt;
  final bool? telegramBound;
  final Set<String>? notificationSubscriptions;

  factory IpingUserInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final balance = json['balance'];
    final notifications = json['notify_subscriptions'];
    if (id is! int ||
        id <= 0 ||
        email is! String ||
        email.isEmpty ||
        balance is! num ||
        !balance.isFinite) {
      throw const FormatException('Invalid user information');
    }
    return IpingUserInfo(
      id: id,
      email: email,
      balance: balance.toDouble(),
      status: json['status'] is String ? json['status'] as String : '',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      telegramBound: json.containsKey('tg_id')
          ? json['tg_id'] is String && (json['tg_id'] as String).isNotEmpty
          : null,
      notificationSubscriptions:
          notifications is List && notifications.every((item) => item is String)
          ? Set.unmodifiable(notifications.cast<String>())
          : null,
    );
  }
}
