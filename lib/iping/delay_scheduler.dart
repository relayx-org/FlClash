import 'dart:async';

import '../common/task_pool.dart';
import '../models/delay.dart';

class IpingDelayTarget {
  const IpingDelayTarget({
    required this.proxyName,
    required this.testUrl,
    required this.key,
  });
  final String proxyName;
  final String testUrl;
  final String key;
}

class _DelayJob {
  _DelayJob(Iterable<String> keys) : held = keys.toSet();
  final Set<String> held;
  final runningOnDispatch = <String>{};
  bool cancelled = false;
  bool silent = false;
  final stopped = Completer<void>();
}

class IpingDelayScheduler {
  IpingDelayScheduler({
    required int concurrency,
    required this.test,
    required this.onAcquire,
    required this.onStart,
    required this.onFinish,
    required this.onValue,
    required this.onSettled,
    required this.onError,
  }) : _pool = TaskPool(concurrency);

  final TaskPool _pool;
  final Future<Delay?> Function(IpingDelayTarget target) test;
  final void Function(Set<String> acquired, Set<String> running) onAcquire;
  final void Function(String key) onStart;
  final void Function(String key) onFinish;
  final void Function(Delay value) onValue;
  final void Function(Iterable<String> finished, Iterable<String> released)
  onSettled;
  final bool Function(IpingDelayTarget target, Object error, StackTrace stack)
  onError;
  final _jobs = <_DelayJob>[];

  void cancel() {
    for (final job in _jobs) {
      job.cancelled = true;
      job.silent = true;
      job.held.clear();
      if (!job.stopped.isCompleted) job.stopped.complete();
    }
  }

  Future<Map<String, Delay>> run(List<IpingDelayTarget> targets) async {
    if (targets.isEmpty) return {};
    final job = _DelayJob(targets.map((target) => target.key));
    final results = <String, Delay>{};
    _jobs.add(job);
    job.runningOnDispatch.addAll(
      targets.take(_pool.idleSlots).map((target) => target.key),
    );
    onAcquire(job.held, job.runningOnDispatch);
    try {
      final running = Future.wait(
        targets.map(
          (target) => _pool.run(() async {
            if (job.cancelled) return;
            if (!job.runningOnDispatch.contains(target.key)) {
              onStart(target.key);
            }
            try {
              final value = await test(target);
              if (job.cancelled) return;
              if (value == null || value.value == null) {
                job.cancelled = true;
                job.stopped.complete();
              } else {
                results[target.key] = value;
                onValue(value);
              }
            } catch (error, stack) {
              if (!job.cancelled && onError(target, error, stack)) {
                job.cancelled = true;
                job.stopped.complete();
              }
            } finally {
              if (job.held.remove(target.key)) onFinish(target.key);
            }
          }),
        ),
      );
      await Future.any([running, job.stopped.future]);
      return results;
    } finally {
      _jobs.remove(job);
      final remaining = job.held.toList();
      job.held.clear();
      if (!job.silent) {
        onSettled(
          remaining.where(job.runningOnDispatch.contains),
          remaining.where((key) => !job.runningOnDispatch.contains(key)),
        );
      }
    }
  }
}
