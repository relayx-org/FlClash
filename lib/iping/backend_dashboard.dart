import 'backend_settings.dart';

class IpingDashboardSnapshot {
  const IpingDashboardSnapshot({
    this.localIp = '',
    this.started,
    this.groups = 0,
    this.proxies = 0,
    this.rules = 0,
    required this.settings,
  });

  factory IpingDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] as Map? ?? {});
    final started = (json['started'] as num?)?.toInt() ?? 0;
    return IpingDashboardSnapshot(
      localIp: json['local_ip'] as String? ?? '',
      started: started > 0
          ? DateTime.fromMillisecondsSinceEpoch(started)
          : null,
      groups: (counts['groups'] as num?)?.toInt() ?? 0,
      proxies: (counts['proxies'] as num?)?.toInt() ?? 0,
      rules: (counts['rules'] as num?)?.toInt() ?? 0,
      settings: IpingSettings(
        Map<String, Object?>.from(json['settings'] as Map? ?? {}),
      ),
    );
  }

  final String localIp;
  final DateTime? started;
  final int groups;
  final int proxies;
  final int rules;
  final IpingSettings settings;
}
