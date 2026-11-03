import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'account_statistics.dart';
import 'topup.dart';

class IpingRenewalWarning extends StatelessWidget {
  const IpingRenewalWarning({
    super.key,
    required this.count,
    required this.cost,
    required this.shortfall,
    required this.onTopUp,
  });

  final int count;
  final double cost;
  final double shortfall;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final foreground = scheme.onWarningContainer;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.warningContainer,
        shape: AppShape.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          spacing: 12,
          children: [
            GlyphIcon(
              AppGlyphs.warning,
              size: 20.ap(context),
              color: foreground,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    l.ipingRenewalShortfall,
                    style: AppTextStyle.subheadline
                        .of(context, emphasized: true)
                        .copyWith(color: foreground),
                  ),
                  Text(
                    l.ipingRenewalShortfallDetail(
                      count,
                      ipingCurrency(cost),
                      ipingCurrency(shortfall),
                    ),
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: foreground),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTopUp,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(l.ipingTopUp),
            ),
          ],
        ),
      ),
    );
  }
}

class IpingReferralSection extends StatelessWidget {
  const IpingReferralSection({super.key, required this.stats});

  final IpingReferralStats stats;

  Future<void> _share() => shareText(stats.link);

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: stats.link));
    if (!context.mounted) return;
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }

  Widget _value(BuildContext context, String title, String value) => ListItem(
    title: Text(title),
    trailing: Text(
      value,
      style: context.listTitleStyle.toTabular.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return generateSection(
      title: l.ipingReferralInformation,
      footer: l.ipingReferralHint,
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(l.ipingReferralLink),
          subtitle: Text(
            stats.link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l.share,
                onPressed: _share,
                icon: const GlyphIcon(AppGlyphs.upload),
              ),
              IconButton(
                tooltip: l.copyLink,
                onPressed: () => _copy(context),
                icon: const GlyphIcon(AppGlyphs.copy),
              ),
            ],
          ),
          onTap: () => _copy(context),
        ),
        _value(context, l.ipingReferralCount, '${stats.count}'),
        _value(context, l.ipingReferralEarnings, ipingCurrency(stats.earnings)),
        _value(
          context,
          l.ipingReferralRate,
          '${stats.commissionRate.fixed()}%',
        ),
      ],
    );
  }
}
