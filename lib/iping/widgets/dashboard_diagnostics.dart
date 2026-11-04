import 'package:fl_clash/common/datetime.dart';
import 'package:fl_clash/common/num.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showDashboardDiagnostics(
  BuildContext context, {
  required IpingDashboardHost host,
}) => showSheet<void>(
  context: context,
  builder: (_) => _IpingDashboardDiagnostics(host: host),
);

class _IpingDashboardDiagnostics extends StatefulWidget {
  const _IpingDashboardDiagnostics({required this.host});

  final IpingDashboardHost host;

  @override
  State<_IpingDashboardDiagnostics> createState() =>
      _IpingDashboardDiagnosticsState();
}

class _IpingDashboardDiagnosticsState
    extends State<_IpingDashboardDiagnostics> {
  late final Listenable _updates = Listenable.merge([
    widget.host,
    widget.host.probes,
    widget.host.telemetryUpdates,
  ]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.ipingDiagnostics,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.refresh,
        tooltip: l.ipingRunDiagnostics,
        onPressed: widget.host.probes.outbound.refreshOutbound,
      ),
      body: ListenableBuilder(
        listenable: _updates,
        builder: (context, _) {
          final host = widget.host;
          final entry = host.probes.outbound.state.entryOf('');
          final ip = entry.value?.ip;
          final outbound =
              ip ??
              (entry.phase == ProbePhase.failed ? l.serviceFailed : l.noData);
          return ListView(
            padding: EdgeInsets.fromLTRB(0, context.contentTopPadding, 0, 24),
            children: [
              ListHeader(title: l.ipingDiagnostics),
              ListItem(
                title: Text(l.status),
                trailing: Text(host.connected ? l.running : l.notRunning),
              ),
              ListItem(title: Text(l.nodes), trailing: Text('${host.nodes}')),
              ListItem(
                title: Text(l.lastUpdated),
                trailing: Text(host.updated?.showFull ?? l.noData),
              ),
              ListItem(title: Text(l.outboundIp), trailing: Text(outbound)),
              ListItem(
                title: Text(l.memoryInfo),
                trailing: Text(host.telemetry.memory.traffic.show),
              ),
            ],
          );
        },
      ),
    );
  }
}
