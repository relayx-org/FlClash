import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'providers.dart';

Future<void> showIpingDiagnostics(BuildContext context) => showSheet<void>(
  context: context,
  props: nestedPagedSheetProps,
  builder: (_) => NestedPagedSheet(builder: (_) => const IpingDiagnostics()),
);

class IpingDiagnostics extends ConsumerStatefulWidget {
  const IpingDiagnostics({super.key});

  @override
  ConsumerState<IpingDiagnostics> createState() => _IpingDiagnosticsState();
}

class _IpingDiagnosticsState extends ConsumerState<IpingDiagnostics> {
  OutboundIpProbe? _probe;

  @override
  void initState() {
    super.initState();
    if (!ref.read(safeModeProvider)) {
      final probe = ref.read(outboundIpProbeProvider.notifier);
      probe.watch(routedOutbound);
      _probe = probe;
    }
  }

  @override
  void dispose() {
    _probe?.unwatch(routedOutbound);
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(ipingDnsProvider);
    ref.invalidate(ipingUserInfoProvider);
    if (ref.read(isStartProvider) && !ref.read(suspendProvider)) {
      _probe?.refresh(const [routedOutbound]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final session = ref.watch(ipingSessionProvider);
    final dns = ref.watch(ipingDnsProvider);
    final info = ref.watch(ipingUserInfoProvider);
    final safe = ref.watch(safeModeProvider);
    final running = ref.watch(isStartProvider);
    final suspended = running && ref.watch(suspendProvider);
    final entry = safe
        ? null
        : ref.watch(outboundIpProbeProvider).entryOf(routedOutbound);
    final busy =
        dns.isLoading ||
        info.isLoading ||
        !safe && running && !suspended && entry?.isLoading == true;
    final sessionExpired =
        info.error is IpingException &&
        (info.error as IpingException).failure == IpingFailure.session;
    final subscriptionFailed = session.failure == IpingFailure.subscription;
    return CommonScaffold(
      title: l.ipingDiagnostics,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.refresh,
        tooltip: l.ipingRunDiagnostics,
        isLoading: busy,
        onPressed: busy ? null : _refresh,
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.appBarInset,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            generateSection(
              title: l.ipingDiagnostics,
              items: [
                _CheckRow(
                  title: l.ipingSubscriptionCheck,
                  ok: session.nodes > 0 && !subscriptionFailed,
                  message: subscriptionFailed
                      ? l.ipingSubscriptionError
                      : session.nodes > 0
                      ? '${l.ipingNodeCount(session.nodes)}${session.updated == null ? '' : '\n${session.updated!.showFull}'}'
                      : session.manualUrl != null
                      ? l.ipingManualNoNodes
                      : l.ipingNoNodes,
                ),
                if (session.account != null)
                  _CheckRow(
                    title: l.ipingApiKey,
                    ok: info.value != null && info.value!.status == 'active',
                    message: session.account?.apiKey == null
                        ? l.ipingAccountAuthorizeHint
                        : info.isLoading
                        ? l.ipingSyncing
                        : sessionExpired
                        ? l.ipingSessionExpired
                        : info.hasError
                        ? l.ipingAccountLoadFailed
                        : info.value?.status == 'active'
                        ? l.ipingApiAuthorized
                        : l.ipingAccountInactive,
                    pending: info.isLoading,
                  ),
                _CheckRow(
                  title: l.ipingSystemDns(
                    Uri.parse(ref.watch(ipingApiProvider).site).host,
                  ),
                  ok: dns.value == true,
                  pending: dns.isLoading,
                  message: dns.isLoading
                      ? l.ipingSyncing
                      : dns.value == true
                      ? l.ipingDnsOk
                      : l.ipingDnsFailed,
                ),
                _CheckRow(
                  title: l.ipingProxyCheck,
                  ok: !safe && running && !suspended,
                  message: safe
                      ? l.ipingSafeDiagnostics
                      : suspended
                      ? l.suspended
                      : running
                      ? l.running
                      : l.ipingStartToCheck,
                ),
                _CheckRow(
                  title: l.ipingExitCheck,
                  ok: entry?.phase == ProbePhase.fresh && entry?.value != null,
                  pending:
                      !safe &&
                      running &&
                      !suspended &&
                      entry?.isLoading == true,
                  message: safe
                      ? l.ipingSafeDiagnostics
                      : !running || suspended
                      ? l.ipingStartToCheck
                      : entry?.phase == ProbePhase.failed
                      ? l.ipingExitFailed
                      : entry?.phase == ProbePhase.fresh && entry?.value != null
                      ? l.ipingExitOk
                      : l.ipingSyncing,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                l.ipingDiagnosticsHint,
                style: AppTextStyle.footnote.of(context),
              ),
            ),
            if (session.hasSubscription)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: session.busy
                      ? null
                      : () => ref
                            .read(ipingSessionProvider.notifier)
                            .controller
                            .synchronize(),
                  icon: const GlyphIcon(AppGlyphs.refresh),
                  label: Text(session.busy ? l.ipingSyncing : l.ipingSync),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.message,
    required this.ok,
    this.pending = false,
  });
  final String title;
  final String message;
  final bool ok;
  final bool pending;

  @override
  Widget build(BuildContext context) => ListItem(
    leading: pending
        ? const CommonCircleLoading()
        : GlyphIcon(
            ok ? AppGlyphs.check : AppGlyphs.info,
            color: ok
                ? context.colorScheme.primary
                : context.colorScheme.onSurfaceVariant,
          ),
    title: Text(title),
    subtitle: Text(message),
  );
}
