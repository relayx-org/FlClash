import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'country_continent.dart';
import 'store_widgets.dart';
import 'tunnel.dart';
import 'tunnel_digest.dart';

String ipingProxyUrl(IpingUserProxy proxy) {
  final auth = proxy.username.isEmpty && proxy.password.isEmpty
      ? ''
      : '${Uri.encodeComponent(proxy.username)}:'
            '${Uri.encodeComponent(proxy.password)}@';
  return '${proxy.type}://$auth${proxy.endpoint}';
}

bool _matches(IpingUserProxy proxy, String query) {
  if (query.isEmpty) return true;
  return [
    proxy.endpoint,
    ?proxy.country,
    ?proxy.city,
    ?proxy.remarks,
  ].any((part) => part.toLowerCase().contains(query));
}

class IpingOwnedNativeIps extends ConsumerWidget {
  const IpingOwnedNativeIps({super.key, required this.query});

  final String query;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final proxies = ref.watch(ipingUserProxiesProvider);
    final all = proxies.value;
    final needle = query.trim().toLowerCase();
    final visible = [
      for (final proxy in all ?? const <IpingUserProxy>[])
        if (_matches(proxy, needle)) proxy,
    ];
    final failed = all == null && proxies.hasError;
    final error = proxies.error;
    return NullStatusSwitcher(
      isLoading: proxies.isLoading && all == null,
      isEmpty: visible.isEmpty,
      isSearching: needle.isNotEmpty && !failed,
      nullStatus: NullStatus(
        illustration: failed
            ? NullStatusIllustration.error
            : NullStatusIllustration.data,
        label: failed
            ? error is IpingException && error.failure == IpingFailure.session
                  ? l.ipingSessionExpired
                  : l.ipingNativeIpLoadFailed
            : l.ipingNativeIpOwnedEmpty,
        action: failed
            ? TextButton(
                onPressed: () => ref.invalidate(ipingUserProxiesProvider),
                child: Text(l.retry),
              )
            : null,
      ),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + BottomInsetScope.of(context),
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: ipingCardGap),
        itemBuilder: (context, index) {
          final proxy = visible[index];
          return ContextMenuRegion(
            menuItems: [
              CommonPopupMenuItem(
                label: l.ipingNativeIpCopyAddress,
                glyph: AppGlyphs.copy,
                onPressed: () => _copy(context, proxy.endpoint),
              ),
              CommonPopupMenuItem(
                label: l.ipingNativeIpCopyCredentials,
                glyph: AppGlyphs.key,
                onPressed: () => _copy(context, proxy.credentials),
              ),
              CommonPopupMenuItem(
                label: l.ipingNativeIpCopyUrl,
                glyph: AppGlyphs.link,
                onPressed: () => _copy(context, ipingProxyUrl(proxy)),
              ),
              CommonPopupMenuItem(
                label: l.ipingNativeIpOpenTunnels,
                glyph: AppGlyphs.split,
                onPressed: () => ref
                    .read(currentPageLabelProvider.notifier)
                    .toPage(PageLabel.tunnels),
              ),
            ],
            child: _OwnedIpCard(
              proxy: proxy,
              onCopy: () => _copy(context, proxy.credentials),
            ),
          );
        },
      ),
    );
  }
}

class _OwnedIpCard extends StatelessWidget {
  const _OwnedIpCard({required this.proxy, required this.onCopy});

  final IpingUserProxy proxy;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final country = proxy.country ?? '';
    final flag = country.isEmpty ? null : countryFlagEmoji(country);
    final place = [
      for (final part in [proxy.country, proxy.city, proxy.remarks])
        if (part != null && part.isNotEmpty) part,
    ].join(' · ');
    final expiry = proxy.expiredAt;
    final expired = proxy.isExpired;
    final soon =
        !expired &&
        expiry != null &&
        expiry.difference(DateTime.now()) <= ipingExpiryNotice;
    final neutral = context.raisedSurfaceLevel.colorOf(scheme);
    return CommonCard(
      radius: ipingCardCorner,
      padding: ipingCardPadding,
      onPressed: onCopy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IpingCardMark(
                child: flag == null
                    ? const GlyphIcon(AppGlyphs.vpn)
                    : EmojiText(flag, style: AppTextStyle.title2.of(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proxy.endpoint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(context).toTabular,
                    ),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.listCaptionStyle,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l.ipingNativeIpCopyCredentials,
                onPressed: onCopy,
                icon: const GlyphIcon(AppGlyphs.copy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MetaChip(label: proxy.type.toUpperCase()),
              if (expiry != null)
                TonalChip(
                  label: expired
                      ? l.ipingTunnelExpired
                      : '${l.ipingTunnelExpires} ${expiry.show}',
                  color: expired
                      ? scheme.errorContainer
                      : soon
                      ? scheme.warningContainer
                      : neutral,
                  foregroundColor: expired
                      ? scheme.onErrorContainer
                      : soon
                      ? scheme.onWarningContainer
                      : scheme.onSurfaceVariant,
                ),
              if (proxy.autoRenew)
                TonalChip(
                  label: l.ipingTunnelAutoRenew,
                  color: neutral,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              if (proxy.inTunnel)
                TonalChip(
                  label: l.ipingNativeIpInTunnel,
                  color: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
