import 'package:fl_clash/iping/backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('traffic sampling preserves immutable bounded snapshots', () {
    final sampler = IpingTrafficSampler(capacity: 2);
    final start = DateTime.utc(2026);
    final first = sampler.add(const Traffic(up: 100, down: 200), start);
    final second = sampler.add(
      const Traffic(up: 600, down: 1200),
      start.add(const Duration(milliseconds: 500)),
    );
    expect(first.latest, const Traffic());
    expect(first.samples.length, 1);
    expect(second.latest, const Traffic(up: 1000, down: 2000));
    expect(second.total, const Traffic(up: 600, down: 1200));
    expect(second.revision, greaterThan(first.revision));
    expect(() => second.samples.clear(), throwsUnsupportedError);
    final third = sampler.add(
      const Traffic(up: 1600, down: 3200),
      start.add(const Duration(milliseconds: 1500)),
    );
    expect(third.samples.length, 2);
    expect(third.samples.first, second.latest);
    expect(first.samples.length, 1);
  });

  test('counter resets and reconnects never become traffic spikes', () {
    final sampler = IpingTrafficSampler();
    final start = DateTime.utc(2026);
    sampler.add(const Traffic(up: 1000, down: 2000), start);
    final reset = sampler.add(
      const Traffic(up: 10, down: 3000),
      start.add(const Duration(seconds: 1)),
    );
    expect(reset.latest, const Traffic());
    sampler.reset();
    final reconnected = sampler.add(
      const Traffic(up: 5000, down: 9000),
      start.add(const Duration(seconds: 2)),
    );
    expect(reconnected.samples, [const Traffic()]);
    expect(reconnected.total.up, 5000);
  });

  test('zero and reversed clock intervals produce finite zero rates', () {
    final sampler = IpingTrafficSampler();
    final start = DateTime.utc(2026);
    sampler.add(const Traffic(up: 10), start);
    expect(sampler.add(const Traffic(up: 20), start).latest, const Traffic());
    expect(
      sampler
          .add(
            const Traffic(up: 30),
            start.subtract(const Duration(seconds: 1)),
          )
          .latest,
      const Traffic(),
    );
  });
}
