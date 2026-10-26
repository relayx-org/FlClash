import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/providers/service_status.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/probe_start_hold.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'service_frame.dart';
import 'service_detail.dart';

const _shownServiceCount = 4;

class ServiceStatusCard extends ConsumerStatefulWidget {
  const ServiceStatusCard({super.key});

  @override
  ConsumerState<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends ConsumerState<ServiceStatusCard>
    with ProbeStartHold<ServiceStatusCard> {
  late final ServiceStatus _services;
  Set<ServiceTarget> _shown = const {};
  Set<ServiceTarget> _watched = const {};
  var _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _services = ref.read(serviceStatusProvider.notifier);
  }

  @override
  void dispose() {
    for (final target in _watched) {
      _services.unwatch(target);
    }
    super.dispose();
  }

  void _watchShown(Set<ServiceTarget> shown) {
    if (setEquals(shown, _shown)) return;
    _shown = shown;
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      final shown = _shown;
      for (final target in shown.difference(_watched)) {
        _services.watch(target);
      }
      for (final target in _watched.difference(shown)) {
        _services.unwatch(target);
      }
      _watched = shown;
    });
  }

  Future<void> _openSheet() => showServiceStatusSheet(context);

  @override
  Widget build(BuildContext context) {
    final shown = ref
        .watch(enabledServiceTargetsProvider)
        .take(_shownServiceCount)
        .toList();
    _watchShown(shown.toSet());
    final state = ref.watch(serviceStatusProvider);
    final services = [
      for (final target in shown)
        DashboardServiceView(
          target,
          shownPhase(state.entryOf(target)) == state.entryOf(target).phase
              ? state.entryOf(target).value
              : null,
          loading: shownPhase(state.entryOf(target)) == ProbePhase.probing,
          failed: shownPhase(state.entryOf(target)) == ProbePhase.failed,
        ),
    ];
    return DashboardServiceCard(
      services: services,
      loading: shown.any(state.isLoading),
      onRefresh: () => _services.refresh(shown),
      onDetails: _openSheet,
    );
  }
}

mixin _NodeAddressWatch<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final OutboundIpProbe _ips;
  String? _node;

  @override
  void initState() {
    super.initState();
    _ips = ref.read(outboundIpProbeProvider.notifier);
  }

  @override
  void dispose() {
    _showNode(null);
    super.dispose();
  }

  void _showNode(String? node) {
    final previous = _node;
    if (node == previous) return;
    _node = node;
    if (node != null) _ips.watch(node);
    if (previous != null) _ips.unwatch(previous);
  }
}

/// Node names tend to carry their own flag emoji, so a service shows where
/// its traffic leaves from as a flag and the address instead, and falls
/// back to the node only when the address could not be looked up.
class _OutboundIpLine extends StatelessWidget {
  const _OutboundIpLine({
    required this.ip,
    required this.region,
    required this.pending,
    required this.fallback,
    required this.style,
  });

  final IpInfo? ip;
  final String? region;
  final bool pending;
  final String? fallback;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ip = this.ip;
    final fallback = this.fallback;
    final flag = ip?.countryCode ?? region;
    if (flag == null && ip == null && !pending && fallback == null) {
      return _NoValue(style: style);
    }
    final line = Row(
      spacing: 4,
      children: [
        if (flag != null)
          Text(
            flag.countryFlagEmoji,
            style: style?.copyWith(fontFamily: FontFamily.twEmoji.value),
          ),
        if (ip != null)
          Flexible(
            child: IpQualityText(ip: ip.ip, style: style),
          )
        else if (pending)
          Flexible(child: SkeletonText(width: 88, style: style))
        else if (fallback != null)
          Flexible(
            child: Text(
              fallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
    if (ip == null) return line;
    return Tooltip(
      message: context.appLocalizations.outboundIp,
      child: InkWell(
        onTap: () => showIpQualitySheet(context, ip: ip.ip),
        customBorder: AppShape.xs,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: line,
      ),
    );
  }
}

class _NoValue extends StatelessWidget {
  const _NoValue({this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        '—',
        style: style?.copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// The status dot sits in a notch cleared from the tile rather than on a ring
/// painted in the surface colour, which differs between the card and the rows.
Future<void> showServiceStatusSheet(BuildContext context) {
  return showSheet<void>(
    context: context,
    props: nestedPagedSheetProps,
    builder: (_) =>
        NestedPagedSheet(builder: (_) => const ServiceStatusSheet()),
  );
}

/// Every enabled service, read from the cache and checked only on request.
class ServiceStatusSheet extends ConsumerWidget {
  const ServiceStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(enabledServiceTargetsProvider);
    final state = ref.watch(serviceStatusProvider);
    final services = ref.read(serviceStatusProvider.notifier);
    final localizations = context.appLocalizations;
    return CommonScaffold(
      title: localizations.serviceStatus,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.bolt,
          tooltip: localizations.serviceCheckAll,
          isLoading: targets.any(state.isLoading),
          onPressed: () => services.refresh(targets),
        ),
        IconButtonData(
          glyph: AppGlyphs.sliders,
          tooltip: localizations.serviceManage,
          onPressed: () => Navigator.of(
            context,
          ).push(PagedSheetRoute(builder: (_) => const ServiceManageView())),
        ),
      ],
      body: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: context.contentTopPadding),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.builder(
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                return ItemPositionProvider(
                  position: ItemPosition.get(index, targets.length),
                  child: _ServiceRow(
                    target: target,
                    entry: state.entryOf(target),
                    onCheck: () => services.refresh([target]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceManageView extends ConsumerWidget {
  const ServiceManageView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(serviceTargetsProvider);
    final enabled = ref.watch(enabledServiceTargetsProvider);
    final settings = ref.read(appSettingProvider.notifier);

    void reorder(int oldIndex, int newIndex) {
      settings.update(
        (state) => state.copyWith(
          serviceOrder: [
            for (final target in targets.copyAndReorder(oldIndex, newIndex))
              target.id,
          ],
        ),
      );
    }

    void toggle(ServiceTarget target, bool value) {
      settings.update((state) {
        final disabled = {...state.disabledServices};
        if (value) {
          disabled.remove(target.id);
        } else {
          disabled.add(target.id);
        }
        return state.copyWith(disabledServices: disabled.toList());
      });
    }

    return ServiceManagePage(
      targets: targets,
      enabled: enabled,
      onReorder: reorder,
      onToggle: toggle,
    );
  }
}

class _ServiceRow extends ConsumerStatefulWidget {
  const _ServiceRow({
    required this.target,
    required this.entry,
    required this.onCheck,
  });

  final ServiceTarget target;
  final ProbeEntry<ServiceCheck> entry;
  final VoidCallback onCheck;

  @override
  ConsumerState<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends ConsumerState<_ServiceRow>
    with _NodeAddressWatch<_ServiceRow> {
  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    final target = widget.target;
    final entry = widget.entry;
    final check = entry.value;
    final node = check?.node;
    _showNode(node);
    final ipEntry = node != null
        ? ref.watch(
            outboundIpProbeProvider.select((state) => state.entryOf(node)),
          )
        : null;
    final outboundIp = ipEntry?.value;
    return ServiceCheckRow(
      target: target,
      entry: entry,
      onCheck: widget.onCheck,
      subtitle: _OutboundIpLine(
        ip: outboundIp,
        region: check?.region,
        pending:
            ipEntry != null &&
            ipEntry.phase != ProbePhase.failed &&
            outboundIp == null,
        fallback: node,
        style: secondary,
      ),
    );
  }
}
