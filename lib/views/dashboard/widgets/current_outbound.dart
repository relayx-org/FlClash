export 'outbound_names.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/features/ip_quality/labels.dart';
import 'package:fl_clash/models/ip_quality.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/diagnostics.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/probe_start_hold.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'outbound_frame.dart';
import 'outbound_content.dart';

/// The address the proxied traffic leaves by, next to the start button.
class CurrentOutboundCard extends ConsumerStatefulWidget {
  const CurrentOutboundCard({super.key});

  @override
  ConsumerState<CurrentOutboundCard> createState() =>
      _CurrentOutboundCardState();
}

class _CurrentOutboundCardState extends ConsumerState<CurrentOutboundCard>
    with ProbeStartHold<CurrentOutboundCard> {
  late final OutboundIpProbe _probe;

  @override
  void initState() {
    super.initState();
    _probe = ref.read(outboundIpProbeProvider.notifier)..watch(routedOutbound);
  }

  @override
  void dispose() {
    _probe.unwatch(routedOutbound);
    super.dispose();
  }

  void _refresh(String? ip) {
    _probe.refresh(const [routedOutbound]);
    if (ip != null && ref.read(ipQualityProvider(ip)).hasError) {
      ref.invalidate(ipQualityProvider(ip));
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final hasProfile = ref.watch(
      ipingSessionProvider.select((state) => state.canConnect),
    );
    final isStart = ref.watch(isStartProvider);
    final suspended = isStart && ref.watch(suspendProvider);
    final entry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final ipInfo = entry.value;
    final phase = shownPhase(entry);
    final failed = phase == ProbePhase.failed && ipInfo == null;
    final qualityState = ipInfo == null
        ? null
        : ref.watch(ipQualityProvider(ipInfo.ip));
    final quality = qualityState?.value;
    final qualityLoading =
        qualityState != null && quality == null && qualityState.isLoading;
    final loading = ipInfo == null ? !failed : qualityLoading;
    final metrics = OutboundCardMetrics.of(density);
    final appLocalizations = context.appLocalizations;
    return DashboardOutboundCard(
      running: isStart,
      suspended: suspended,
      ip: ipInfo?.ip,
      countryCode: ipInfo?.countryCode,
      typeLabel: quality?.type.label(context),
      qualityLabel: quality == null
          ? null
          : '${appLocalizations.ipQualityShort} ${quality.level.label(context)}',
      qualityTone: switch (quality?.level) {
        IpQualityLevel.good => DashboardChipTone.ok,
        IpQualityLevel.risky => DashboardChipTone.warn,
        _ => DashboardChipTone.idle,
      },
      organization: switch (quality) {
        IpQuality(organization: final name?) when name.isNotEmpty => name,
        IpQuality(asn: final asn?) => 'AS$asn',
        _ => null,
      },
      failed: failed,
      loading: loading,
      checking: phase == ProbePhase.probing || qualityLoading,
      hideIp: ref.watch(appSettingProvider.select((state) => state.hideIp)),
      onRefresh: () => _refresh(ipInfo?.ip),
      onDetails: ipInfo == null
          ? null
          : () => showIpQualitySheet(context, ip: ipInfo.ip),
      runTime: const _RunTimeValue(),
      toggle: _StartToggle(
        size: metrics.buttonSize,
        enabled: hasProfile,
        running: isStart,
        suspended: suspended,
      ),
      action: DashboardIconButton(
        glyph: AppGlyphs.search,
        tooltip: appLocalizations.ipingDiagnostics,
        onPressed: () => showIpingDiagnostics(context),
      ),
    );
  }
}

class _RunTimeValue extends ConsumerWidget {
  const _RunTimeValue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      getTimeText(ref.watch(runTimeProvider)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.subheadline.of(context, emphasized: true).toTabular,
    );
  }
}

class _StartToggle extends ConsumerWidget {
  const _StartToggle({
    required this.size,
    required this.enabled,
    required this.running,
    required this.suspended,
  });

  final double size;
  final bool enabled;
  final bool running;
  final bool suspended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    return ConnectionToggle(
      size: size,
      enabled: enabled,
      running: running,
      suspended: suspended,
      tooltip: suspended
          ? l.suspended
          : running
          ? l.stop
          : l.start,
      disabledColor: DashboardColors.of(context).tone2,
      onPressed: () => ref.read(commonActionProvider.notifier).toggleRunning(),
    );
  }
}
