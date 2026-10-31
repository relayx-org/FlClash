import 'package:material_ui/material_ui.dart';

import '../common/datetime.dart';
import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'topup.dart';
import 'user_info.dart';

class IpingProfileHeader extends StatelessWidget {
  const IpingProfileHeader({
    super.key,
    required this.info,
    required this.onTopUp,
  });
  final IpingUserInfo info;
  final VoidCallback? onTopUp;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final level = context.raisedSurfaceLevel;
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final active = info.status == 'active';
    final joined = info.createdAt;
    final telegram = switch (info.telegramBound) {
      true => l.ipingTelegramBound,
      false => l.ipingTelegramUnbound,
      null => null,
    };
    final details = [
      if (joined != null) '${l.ipingJoinedAt} ${joined.show}',
      if (telegram != null) '${l.ipingTelegram} $telegram',
    ];
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: level.colorOf(colorScheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(email: info.email),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.headline
                              .of(context)
                              .copyWith(color: colorScheme.onSurface),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            details.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TonalChip(
                    label: active
                        ? l.ipingAccountActive
                        : l.ipingAccountInactive,
                    color: active
                        ? colorScheme.successContainer
                        : colorScheme.errorContainer,
                    foregroundColor: active
                        ? colorScheme.onSuccessContainer
                        : colorScheme.onErrorContainer,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l.ipingAvailableBalance, style: secondary),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        ipingCurrency(info.balance),
                        maxLines: 1,
                        style: AppTextStyle.largeTitle
                            .of(context, emphasized: true)
                            .toTabular
                            .copyWith(color: colorScheme.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onTopUp,
                    icon: const GlyphIcon(AppGlyphs.add, fill: 1),
                    label: Text(l.ipingTopUp),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.email});
  final String email;
  static const _size = 48.0;
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.circle,
        ),
        child: SizedBox.square(
          dimension: _size,
          child: Center(
            child: Text(
              email.characters.first.toUpperCase(),
              style: AppTextStyle.title3
                  .of(context, emphasized: true)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class IpingTopupStatusChip extends StatelessWidget {
  const IpingTopupStatusChip({super.key, required this.status});
  final IpingTopupStatus status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    return switch (status) {
      IpingTopupStatus.success => TonalChip(
        label: l.ipingTopupStatusSuccess,
        color: colorScheme.successContainer,
        foregroundColor: colorScheme.onSuccessContainer,
      ),
      IpingTopupStatus.pending => TonalChip(
        label: l.ipingTopupStatusPending,
        color: colorScheme.warningContainer,
        foregroundColor: colorScheme.onWarningContainer,
      ),
      IpingTopupStatus.cancelled => TonalChip(
        label: l.ipingTopupStatusCancelled,
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    };
  }
}

/// A pending order pays on a tap; its context menu also cancels it.
class IpingTopupOrderItem extends StatelessWidget {
  const IpingTopupOrderItem({
    super.key,
    required this.order,
    this.onPay,
    this.onCancel,
  });
  final IpingTopupOrder order;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final pending = order.status == IpingTopupStatus.pending;
    final created = order.createdAt?.showFull;
    return ContextMenuRegion(
      menuItems: pending
          ? [
              CommonPopupMenuItem(
                label: l.ipingTopupPay,
                glyph: AppGlyphs.openExternal,
                onPressed: onPay,
              ),
              CommonPopupMenuItem(
                label: l.ipingTopupCancel,
                glyph: AppGlyphs.close,
                danger: true,
                onPressed: onCancel,
              ),
            ]
          : null,
      child: DecorationListItem(
        onPressed: pending ? onPay : null,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: ipingCurrency(order.price),
                style: AppTextStyle.body
                    .of(context, emphasized: true)
                    .toTabular,
              ),
              if (order.bonus > 0)
                TextSpan(
                  text: '  ${l.ipingTopupBonus(ipingCurrency(order.bonus))}',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (order.paymentName.isNotEmpty) order.paymentName,
            if (created != null) created.substring(0, 16),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IpingTopupStatusChip(status: order.status),
      ),
    );
  }
}
