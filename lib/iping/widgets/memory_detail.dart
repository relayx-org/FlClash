import 'package:fl_clash/common/num.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_summary.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showIpingMemoryDetail(
  BuildContext context, {
  required IpingDashboardHost host,
}) => showSheet<void>(
  context: context,
  builder: (_) => _IpingMemoryDetail(host: host),
);

class _IpingMemoryDetail extends StatelessWidget {
  const _IpingMemoryDetail({required this.host});

  final IpingDashboardHost host;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.memoryInfo,
      body: ListenableBuilder(
        listenable: host.telemetryUpdates,
        builder: (context, _) {
          final core = host.telemetry.memory;
          final running = host.connected && core > 0;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, context.contentTopPadding, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.total,
                      style: AppTextStyle.headline
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      core.traffic.show,
                      style: AppTextStyle.title1.of(context, emphasized: true),
                    ),
                    const SizedBox(height: 16),
                    DashboardMemoryBar(
                      segments: [
                        (
                          bytes: core,
                          color: DashboardColors.of(context).series2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.memoryCoreOnlyDesc,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListHeader(title: l.core),
              if (running)
                ListItem(
                  title: Text(l.memoryCoreResident),
                  trailing: Text(core.traffic.show),
                )
              else
                ListItem(title: Text(l.memoryCoreNotRunning)),
              const SizedBox(height: 8),
              ListHeader(title: l.app),
              ListItem(
                title: Text(l.memoryAppUnavailable),
                subtitle: Text(l.memoryCoreOnlyDesc),
              ),
            ],
          );
        },
      ),
    );
  }
}
