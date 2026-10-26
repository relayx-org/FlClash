import 'package:fl_clash/common/routed_probe.dart';
import 'package:fl_clash/common/service_probe_data.dart';
import 'package:fl_clash/common/datetime.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'service_frame.dart';

class _ServiceTitle extends StatelessWidget {
  const _ServiceTitle({required this.name, required this.status});

  static const _statusShare = 0.6;

  final String name;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // A Flexible status would cap the name at its own share even when the
      // status is short, so the status takes what it needs up to a limit.
      builder: (context, constraints) => Row(
        spacing: 8,
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * _statusShare,
            ),
            child: status,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.colors});

  final String label;
  final DashboardServiceColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.container,
        shape: AppShape.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .copyWith(color: colors.onContainer),
        ),
      ),
    );
  }
}

const _rowBadgeSize = 40.0;
const _rowBadgeInset = 12.0;
// Concentric with the corners DecorationListItem gives the ends of a run.
const _rowBadgeRadius = AppCorner.xl - _rowBadgeInset;

class _ServiceManageItem extends StatelessWidget {
  const _ServiceManageItem({
    super.key,
    required this.target,
    required this.index,
    required this.position,
    required this.enabled,
    required this.shown,
    required this.onChanged,
  });

  final ServiceTarget target;
  final int index;
  final ItemPosition position;
  final bool enabled;
  final bool shown;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ItemPositionProvider(
          position: position,
          child: DecorationListItem(
            minVerticalPadding: _rowBadgeInset,
            contentPadding: const EdgeInsets.only(
              left: _rowBadgeInset,
              right: 16,
            ),
            onPressed: onChanged == null ? null : () => onChanged(!enabled),
            leading: DashboardServiceBadge(
              target: target,
              size: _rowBadgeSize,
              radius: _rowBadgeRadius,
              enabled: enabled,
            ),
            title: Text(
              target.label,
              style: enabled
                  ? null
                  : TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
            subtitle: shown
                ? Text(AppLocalizations.of(context).serviceShownOnDashboard)
                : null,
            trailing: Switch(value: enabled, onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}

class ServiceCheckRow extends StatelessWidget {
  const ServiceCheckRow({
    super.key,
    required this.target,
    required this.entry,
    required this.onCheck,
    required this.subtitle,
  });
  final ServiceTarget target;
  final ProbeEntry<ServiceCheck> entry;
  final VoidCallback onCheck;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    final check = entry.value;
    final loading = entry.isLoading;
    final (label, colors) = dashboardServiceStatusOf(
      context,
      check,
      loading: entry.phase == ProbePhase.probing,
      failed: entry.phase == ProbePhase.failed,
    );
    return DecorationListItem(
      minVerticalPadding: _rowBadgeInset,
      contentPadding: const EdgeInsets.only(left: _rowBadgeInset, right: 4),
      onPressed: loading ? null : onCheck,
      leading: DashboardServiceBadge(
        target: target,
        size: _rowBadgeSize,
        radius: _rowBadgeRadius,
        dot: loading
            ? context.colorScheme.onSurfaceVariant
            : check != null || entry.phase == ProbePhase.failed
            ? colors.color
            : null,
      ),
      title: _ServiceTitle(
        name: target.label,
        status: _StatusPill(label: label, colors: colors),
      ),
      // A one-line tile is shorter than a two-line one, so the line is always
      // there and a check does not resize the row.
      subtitle: loading ? SkeletonText(width: 96, style: secondary) : subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          _ServiceRowTrailing(check: check, style: secondary),
          IconButton(
            tooltip: localizations.serviceCheck,
            onPressed: loading ? null : onCheck,
            icon: const GlyphIcon(AppGlyphs.refresh),
          ),
        ],
      ),
    );
  }
}

class _ServiceRowTrailing extends StatelessWidget {
  const _ServiceRowTrailing({required this.check, this.style});

  final ServiceCheck? check;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final delay = check?.delay;
    final checkedAt = check?.checkedAt;
    if (delay == null && checkedAt == null) {
      return const SizedBox.shrink();
    }
    final numeric = style?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (delay != null)
          Text(
            '$delay ms',
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .toTabular
                .copyWith(color: context.colorScheme.onSurface),
          ),
        if (checkedAt != null)
          Text(
            checkedAt.showTime.trim(),
            style: numeric?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    if (checkedAt == null) return column;
    return Tooltip(
      message: AppLocalizations.of(
        context,
      ).serviceCheckedAt(checkedAt.showFull),
      child: column,
    );
  }
}

class ServiceManagePage extends StatelessWidget {
  const ServiceManagePage({
    super.key,
    required this.targets,
    required this.enabled,
    required this.onReorder,
    required this.onToggle,
  });
  final List<ServiceTarget> targets;
  final List<ServiceTarget> enabled;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(ServiceTarget target, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final shown = enabled.take(4).toSet();
    Widget itemAt(int index) {
      final target = targets[index];
      final isEnabled = enabled.contains(target);
      final locked = isEnabled && enabled.length == 1;
      return _ServiceManageItem(
        key: ValueKey(target),
        target: target,
        index: index,
        position: ItemPosition.get(index, targets.length),
        enabled: isEnabled,
        shown: shown.contains(target),
        onChanged: locked ? null : (value) => onToggle(target, value),
      );
    }

    return CommonScaffold(
      title: AppLocalizations.of(context).serviceManage,
      body: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: context.contentTopPadding),
          ),
          SliverReorderableList(
            itemBuilder: (_, index) => itemAt(index),
            itemCount: targets.length,
            proxyDecorator: (child, index, animation) =>
                commonProxyDecorator(itemAt(index), index, animation),
            onReorderItem: onReorder,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
