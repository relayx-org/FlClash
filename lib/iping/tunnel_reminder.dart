import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'tunnel_digest.dart';

const ipingTunnelReminderCooldown = Duration(hours: 12);
const ipingTunnelReminderShownKey = 'my.iping.client.tunnel-reminder.shown';

String? ipingTunnelReminderText(IpingTunnelDigest digest) {
  final l = currentAppLocalizations;
  final parts = [
    if (digest.expiring.isNotEmpty)
      l.ipingTunnelReminderExpiring(digest.expiring.length),
    if (digest.trafficLow.isNotEmpty)
      l.ipingTunnelReminderTraffic(digest.trafficLow.length),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class IpingTunnelReminder extends ConsumerStatefulWidget {
  const IpingTunnelReminder({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<IpingTunnelReminder> createState() =>
      _IpingTunnelReminderState();
}

class _IpingTunnelReminderState extends ConsumerState<IpingTunnelReminder> {
  late final AppLifecycleListener _lifecycle;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    ref.listenManual(
      ipingSessionProvider.select((state) => state.account?.apiKey),
      (_, apiKey) {
        if (apiKey != null) unawaited(_check());
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final shown = preferences.getInt(ipingTunnelReminderShownKey);
      if (shown != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(shown),
              ) <
              ipingTunnelReminderCooldown) {
        return;
      }
      final digest = await ref
          .read(ipingAuthenticatedApiProvider)
          .tunnelDigest();
      if (!mounted || ref.read(ipingSessionProvider).account?.apiKey == null) {
        return;
      }
      final text = ipingTunnelReminderText(digest);
      if (text == null) return;
      dialogs.showNotifier(
        text,
        level: MessageLevel.warning,
        actionState: MessageActionState(
          actionText: currentAppLocalizations.view,
          action: () => ref
              .read(currentPageLabelProvider.notifier)
              .toPage(PageLabel.tunnels),
        ),
      );
      await preferences.setInt(
        ipingTunnelReminderShownKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      commonPrint.log('Unable to check tunnel reminders');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
