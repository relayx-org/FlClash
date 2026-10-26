import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import '../layout.dart';
import '../style.dart';
import 'card.dart';

typedef _LanRowMetrics = ({
  EdgeInsets padding,
  double titleStart,
  double radius,
  double icon,
});

class DashboardIntranetCard extends StatelessWidget {
  const DashboardIntranetCard({
    super.key,
    required this.localIp,
    required this.allowLan,
    required this.port,
    required this.onCopy,
    this.onChanged,
  });
  final String? localIp;
  final bool allowLan;
  final int port;
  final ValueChanged<String> onCopy;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final localIp = this.localIp;
    final density = DashboardDensityScope.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    final mobile = !density.isDesktop;
    final appLocalizations = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final figure = mobile
        ? (style: AppTextStyle.title1, top: 12.0)
        : density.isCompact
        ? (style: AppTextStyle.title2, top: 8.0)
        : (style: AppTextStyle.title2, top: 10.0);
    final _LanRowMetrics row = density.isCompact
        ? (
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            titleStart: 12,
            radius: 16,
            icon: 32,
          )
        : (
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            titleStart: 14,
            radius: 20,
            icon: 38,
          );
    final style = DashboardText.figure(
      context,
      figure.style,
    ).copyWith(letterSpacing: 0);
    final address = localIp == null || localIp.isEmpty
        ? null
        : allowLan
        ? '$localIp:$port'
        : localIp;
    return DashboardCard(
      semanticLabel: appLocalizations.intranetIP,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.devices,
            title: appLocalizations.intranetIP,
            trailing: [
              Transform.translate(
                offset: const Offset(8, 0),
                child: DashboardIconButton(
                  glyph: AppGlyphs.copy,
                  tooltip: appLocalizations.copy,
                  onPressed: address == null ? null : () => onCopy(address),
                ),
              ),
            ],
          ),
          SizedBox(height: figure.top),
          SizedBox(
            height: figure.style.leading * scale,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: switch (localIp) {
                null => SkeletonText(width: 120, style: style),
                '' => Text(
                  appLocalizations.noNetwork,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                final ip => DashboardFitText(ip, style: style),
              },
            ),
          ),
          if (mobile) const SizedBox(height: 14) else const Spacer(),
          LayoutBuilder(
            builder: (context, constraints) {
              final title = appLocalizations.allowLan;
              final showIcon = DashboardSwitchRow.iconFits(
                context,
                width: constraints.maxWidth,
                iconSize: row.icon,
                padding: row.padding,
                titles: [title],
              );
              return DashboardSwitchRow(
                glyph: AppGlyphs.wifi,
                title: title,
                subtitle: allowLan
                    ? appLocalizations.portValue(port)
                    : appLocalizations.disabled,
                value: allowLan,
                iconSize: row.icon,
                padding: showIcon
                    ? row.padding
                    : row.padding.copyWith(left: row.titleStart),
                radius: row.radius,
                showIcon: showIcon,
                onTap: onChanged == null ? null : () => onChanged!(!allowLan),
                onChanged: onChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}
