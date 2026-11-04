import '../models/tracker.dart';

class IpingRequest {
  const IpingRequest({
    required this.id,
    required this.time,
    this.host = '',
    this.source = '',
    this.destination = '',
    this.network = '',
    this.rule = '',
    this.rulePayload = '',
    this.chains = const [],
    this.upload = 0,
    this.download = 0,
    this.duration = Duration.zero,
    this.closed = false,
  });

  factory IpingRequest.fromJson(Map<String, Object?> json) {
    final chains = [
      for (final item in json['chains'] as List? ?? const [])
        if (item is String && item.isNotEmpty) item,
    ];
    final seconds = (json['duration'] as num?)?.toInt() ?? 0;
    return IpingRequest(
      id: json['id']?.toString() ?? '',
      time: _timeOf(json['start']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      host: json['host'] as String? ?? '',
      source: json['source'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      network: json['network'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      rulePayload: json['rule_payload'] as String? ?? '',
      chains: chains,
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      duration: Duration(seconds: seconds),
      closed: json['closed'] == true,
    );
  }

  factory IpingRequest.fromTracker(TrackerInfo info, {DateTime? now}) {
    final destination = info.metadata.destinationPort.isEmpty
        ? info.metadata.destinationIP
        : '${info.metadata.destinationIP}:${info.metadata.destinationPort}';
    return IpingRequest(
      id: info.id,
      time: info.start,
      host: info.metadata.host,
      source: info.metadata.process,
      destination: destination,
      network: info.metadata.network,
      rule: info.rule,
      rulePayload: info.rulePayload,
      chains: info.chains,
      upload: info.upload,
      download: info.download,
      duration: (now ?? DateTime.now()).difference(info.start),
    );
  }

  final String id;
  final DateTime time;
  final String host;
  final String source;
  final String destination;
  final String network;
  final String rule;
  final String rulePayload;
  final List<String> chains;
  final int upload;
  final int download;
  final Duration duration;
  final bool closed;

  String get title => host.isNotEmpty ? host : destination;
}

class IpingRequestPage {
  const IpingRequestPage({this.items = const [], this.total = 0});

  final List<IpingRequest> items;
  final int total;
}

DateTime? _timeOf(Object? value) => switch (value) {
  final String text => DateTime.tryParse(text),
  final num milliseconds => DateTime.fromMillisecondsSinceEpoch(
    milliseconds.toInt(),
  ),
  _ => null,
};
