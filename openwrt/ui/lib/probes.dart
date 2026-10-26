import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/features/ip_quality/detail.dart';
import 'package:fl_clash/views/dashboard/widgets/service_detail.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'preferences.dart';

List<ServiceTarget> routerServiceTargets(RouterPreferences preferences) =>
    enabledServices(
      orderServiceTargets(preferences.serviceOrder),
      preferences.disabledServices,
    );

class RouterIpQuality extends StatelessWidget {
  const RouterIpQuality({super.key, required this.ip});
  final String ip;

  @override
  Widget build(BuildContext context) {
    final router = RouterScope.of(context);
    final app = RouterAppState.of(context);
    final l = AppLocalizations.of(context);
    final probes = router.probes;
    final hidden = app.preferences.hideIp;
    void hide(bool value) =>
        app.updatePreferences((settings) => settings.hideIp = value);
    return CommonScaffold(
      title: l.outboundIp,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: l.ipQualityRetry,
          isLoading: probes.isQualityLoading(ip),
          onPressed: () => probes.loadQuality(ip, force: true),
        ),
      ],
      body: IpQualityDetail(
        ip: ip,
        isLoading: probes.isQualityLoading(ip),
        quality: probes.qualityOf(ip),
        error: probes.qualityErrorOf(ip),
        address: Text(hidden ? '*****' : ip),
        other: [
          DecorationListItem(
            title: Text(l.hideIp),
            onPressed: () => hide(!hidden),
            trailing: Switch(value: hidden, onChanged: hide),
          ),
        ],
      ),
    );
  }
}

class RouterServiceStatus extends StatelessWidget {
  const RouterServiceStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final router = RouterScope.of(context);
    final targets = routerServiceTargets(
      RouterAppState.of(context).preferences,
    );
    final l = AppLocalizations.of(context);
    final state = router.probes.services.state;
    return CommonScaffold(
      title: l.serviceStatus,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.bolt,
          tooltip: l.serviceCheckAll,
          isLoading: targets.any(state.isLoading),
          onPressed: () => router.probes.services.refresh(targets),
        ),
        IconButtonData(
          glyph: AppGlyphs.sliders,
          tooltip: l.serviceManage,
          onPressed: () => Navigator.of(
            context,
          ).push(PagedSheetRoute(builder: (_) => const RouterServiceManage())),
        ),
      ],
      body: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        itemCount: targets.length,
        itemBuilder: (context, index) {
          final target = targets[index];
          final entry = router.probes.error == null
              ? state.entryOf(target)
              : const ProbeEntry<ServiceCheck>(phase: ProbePhase.failed);
          return ItemPositionProvider(
            position: ItemPosition.get(index, targets.length),
            child: ServiceCheckRow(
              target: target,
              entry: entry,
              onCheck: () => router.probes.services.refresh([target]),
              subtitle: Text(
                entry.value?.region ?? '—',
                style: AppTextStyle.footnote.of(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RouterServiceManage extends StatelessWidget {
  const RouterServiceManage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = RouterAppState.of(context);
    final targets = orderServiceTargets(app.preferences.serviceOrder);
    return ServiceManagePage(
      targets: targets,
      enabled: routerServiceTargets(app.preferences),
      onReorder: (oldIndex, newIndex) => app.updatePreferences((settings) {
        final ordered = targets.toList();
        ordered.insert(newIndex, ordered.removeAt(oldIndex));
        settings.serviceOrder = [for (final target in ordered) target.id];
      }),
      onToggle: (target, enabled) => app.updatePreferences((settings) {
        final disabled = settings.disabledServices.toSet();
        if (enabled) {
          disabled.remove(target.id);
        } else {
          disabled.add(target.id);
        }
        settings.disabledServices = disabled.toList();
      }),
    );
  }
}
