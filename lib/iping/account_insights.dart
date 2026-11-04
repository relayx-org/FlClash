import 'package:fl_clash/common/num.dart';
import 'package:fl_clash/enum/message_level.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'account_statistics.dart';
import 'notify.dart';
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
    final l = AppLocalizations.of(context);
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
  const IpingReferralSection({super.key, required this.stats, this.onShare});

  final IpingReferralStats stats;

  /// Opens the platform share sheet; a browser falls back to copying the link.
  final Future<void> Function()? onShare;

  Future<void> _share(BuildContext context) async {
    final share = onShare;
    if (share != null) return share();
    await _copy(context);
  }

  Future<void> _copy(BuildContext context) async {
    final l = AppLocalizations.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: stats.link));
      if (!context.mounted) return;
      context.showNotifier(l.copySuccess, level: MessageLevel.success);
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.ipingReferralLink),
          content: SelectableText(stats.link),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.close),
            ),
          ],
        ),
      );
    }
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
    final l = AppLocalizations.of(context);
    return generateSection(
      title: l.ipingReferralInformation,
      footer: l.ipingReferralHint,
      items: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(l.ipingReferralLink),
          subtitle: SelectableText(stats.link, maxLines: 1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l.share,
                onPressed: () => _share(context),
                icon: const GlyphIcon(AppGlyphs.upload),
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
