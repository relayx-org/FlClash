import '../enum/mode.dart';
import '../models/traffic.dart';

export '../enum/mode.dart';
export '../models/traffic.dart';

class IpingTrafficSnapshot {
  IpingTrafficSnapshot({
    required Iterable<Traffic> samples,
    required this.total,
    required this.revision,
    required this.capacity,
  }) : samples = List.unmodifiable(samples);

  const IpingTrafficSnapshot.empty()
    : samples = const [],
      total = const Traffic(),
      revision = 0,
      capacity = 40;

  final List<Traffic> samples;
  final Traffic total;
  final int revision;
  final int capacity;

  Traffic get latest => samples.lastOrNull ?? const Traffic();
}

class IpingTelemetry {
  const IpingTelemetry({
    this.traffic = const IpingTrafficSnapshot.empty(),
    this.connections = 0,
    this.memory = 0,
    this.mode = Mode.rule,
  });

  final IpingTrafficSnapshot traffic;
  final int connections;
  final int memory;
  final Mode mode;
}

class IpingTrafficSampler {
  IpingTrafficSampler({this.capacity = 40}) : assert(capacity > 0);

  final int capacity;
  final _samples = <Traffic>[];
  DateTime? _time;
  Traffic? _total;
  int _revision = 0;

  IpingTrafficSnapshot add(Traffic total, DateTime time) {
    final previous = _total;
    final elapsed = _time == null
        ? 0
        : time.difference(_time!).inMicroseconds /
              Duration.microsecondsPerSecond;
    final continuous =
        previous != null &&
        total.up >= previous.up &&
        total.down >= previous.down &&
        elapsed > 0;
    _samples.add(
      continuous
          ? Traffic(
              up: (total.up - previous.up) / elapsed,
              down: (total.down - previous.down) / elapsed,
            )
          : const Traffic(),
    );
    if (_samples.length > capacity) {
      _samples.removeRange(0, _samples.length - capacity);
    }
    _total = total;
    _time = time;
    return IpingTrafficSnapshot(
      samples: _samples,
      total: total,
      revision: ++_revision,
      capacity: capacity,
    );
  }

  void reset() {
    _time = null;
    _total = null;
    _samples.clear();
  }
}
