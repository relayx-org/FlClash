import 'package:material_ui/material_ui.dart';
import '../../l10n/l10n.dart';
import '../../ui/ui.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({
    super.key,
    this.desktop = false,
    this.notices = const [],
    this.requestsFooter,
    this.startup = const [],
    this.requests = const [],
    this.inbound = const [],
    this.connection = const [],
    this.core = const [],
    this.logs = const [],
    this.startupFooter,
    this.inboundFooter,
  });
  final bool desktop;
  final List<Widget> notices;
  final String? requestsFooter;
  final List<Widget> startup;
  final List<Widget> requests;
  final List<Widget> inbound;
  final List<Widget> connection;
  final List<Widget> core;
  final List<Widget> logs;
  final String? startupFooter;
  final String? inboundFooter;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BaseScaffold(
      title: l.general,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.appBarInset, bottom: 16),
        children: [
          ...notices,
          if (startup.isNotEmpty)
            generateSection(
              title: l.startupAndBackground,
              items: startup,
              footer:
                  startupFooter ??
                  [
                    if (desktop) l.silentLaunchDesc,
                    l.autoRunDesc,
                    l.onDemandDesc,
                  ].join('\n'),
            ),
          if (requests.isNotEmpty)
            generateSection(
              title: l.requestsAndUpdates,
              items: requests,
              footer: requestsFooter ?? l.checkCertificateDesc,
            ),
          if (inbound.isNotEmpty)
            generateSection(
              title: l.inbound,
              items: inbound,
              footer:
                  inboundFooter ??
                  [l.externalControllerDesc, l.authenticationDesc].join('\n'),
            ),
          if (connection.isNotEmpty)
            generateSection(
              title: l.connection,
              items: connection,
              footer: l.autoCloseConnectionsDesc,
            ),
          if (core.isNotEmpty)
            generateSection(title: l.core, items: core, footer: l.ipv6Desc),
          if (logs.isNotEmpty)
            generateSection(
              title: l.logsAndDiagnostics,
              items: logs,
              footer: l.logcatDesc,
            ),
        ],
      ),
    );
  }
}
