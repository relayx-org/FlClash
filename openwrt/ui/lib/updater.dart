import 'dart:async';

import 'package:fl_clash/iping/update_view.dart';
import 'package:flutter/foundation.dart';

import 'client.dart';

class RouterUpdate implements IpingUpdateOffer {
  const RouterUpdate({
    required this.version,
    required this.buildNumber,
    this.notes = '',
  });

  @override
  final String version;
  @override
  final int buildNumber;
  @override
  final String notes;
  @override
  IpingUpdateKind get kind => IpingUpdateKind.router;
  @override
  Uri? get url => null;
}

/// Installs through the Agent's updater, which restarts the Agent and with it
/// this page, so success shows as the Agent returning from the restart.
class RouterUpdater extends ChangeNotifier implements IpingUpdateController {
  RouterUpdater(
    this.client, {
    this.pollInterval = const Duration(seconds: 3),
    this.timeout = const Duration(minutes: 15),
  });

  final RouterClient client;
  final Duration pollInterval;
  final Duration timeout;
  @override
  final bool enabled = true;
  @override
  RouterUpdate? update;
  @override
  bool busy = false;
  @override
  bool failed = false;
  @override
  bool checkFailed = false;
  @override
  double? get progress => null;
  Future<void>? _pending;
  bool _disposed = false;

  @override
  bool get checking => _pending != null;

  @override
  Future<void> check() {
    if (_disposed || busy) return Future.value();
    if (_pending case final pending?) return pending;
    final operation = Future<void>.microtask(_check).whenComplete(() {
      _pending = null;
      if (!_disposed) notifyListeners();
    });
    _pending = operation;
    checkFailed = false;
    notifyListeners();
    return operation;
  }

  Future<void> _check() async {
    try {
      final data = Map<String, Object?>.from(
        await client.call('update_check') as Map,
      );
      if (_disposed) return;
      update = data['available'] == true
          ? RouterUpdate(
              version: data['version']! as String,
              buildNumber: (data['build']! as num).toInt(),
              notes: data['notes'] as String? ?? '',
            )
          : null;
      failed = false;
    } catch (_) {
      if (!_disposed) checkFailed = true;
    }
  }

  @override
  Future<void> install({Future<String?> Function()? askPassword}) async {
    if (update == null || busy || checking || _disposed) return;
    busy = true;
    failed = false;
    notifyListeners();
    try {
      await client.call('update_install');
      if (await _finished()) {
        client.reload();
        return;
      }
    } catch (_) {}
    if (_disposed) return;
    busy = false;
    failed = true;
    notifyListeners();
  }

  Future<bool> _finished() async {
    final deadline = DateTime.now().add(timeout);
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      if (_disposed) return false;
      try {
        final status = Map<String, Object?>.from(
          await client.call('update_status') as Map,
        );
        if (status['running'] != true) return status['failed'] != true;
      } on RouterException catch (error) {
        if (error.message != 'agent_unavailable') return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
