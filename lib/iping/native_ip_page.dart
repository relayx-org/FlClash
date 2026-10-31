import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'country_continent.dart';
import 'native_ip.dart';
import 'native_ip_form.dart';
import 'native_ip_owned.dart';
import 'providers.dart';
import 'store_widgets.dart';
import 'topup.dart';
import 'tunnel_digest.dart';

const _lowStock = 10;

enum _NativeIpTab { buy, owned }

String _continentLabel(AppLocalizations l, String code) => switch (code) {
  'NA' => l.ipingNativeIpContinentNA,
  'SA' => l.ipingNativeIpContinentSA,
  'EU' => l.ipingNativeIpContinentEU,
  'AS' => l.ipingNativeIpContinentAS,
  'OC' => l.ipingNativeIpContinentOC,
  'AF' => l.ipingNativeIpContinentAF,
  'AN' => l.ipingNativeIpContinentAN,
  _ => code,
};

/// Tag tones from the store, drawn with the app's semantic colors.
(Color, Color) _tagColors(BuildContext context, String? tone) {
  final scheme = context.colorScheme;
  return switch (tone) {
    'residential' ||
    'selfServiceSwitch' => (scheme.successContainer, scheme.onSuccessContainer),
    'protocol' ||
    'ipSegment' => (scheme.primaryContainer, scheme.onPrimaryContainer),
    'liveHigh' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    'live' => (scheme.errorContainer, scheme.onErrorContainer),
    'signup' => (scheme.warningContainer, scheme.onWarningContainer),
    'customBandwidth' => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
    ),
    _ => (context.raisedSurfaceLevel.colorOf(scheme), scheme.onSurfaceVariant),
  };
}

List<NativeIpTag> _filterTags(List<NativeIpOffer> offers) {
  final tags = <String, NativeIpTag>{};
  for (final offer in offers) {
    for (final tag in offer.tags) {
      tags.putIfAbsent(tag.key, () => tag);
    }
  }
  return tags.values.toList();
}

class IpingNativeIpPage extends ConsumerStatefulWidget {
  const IpingNativeIpPage({super.key});

  @override
  ConsumerState<IpingNativeIpPage> createState() => _IpingNativeIpPageState();
}

class _IpingNativeIpPageState extends ConsumerState<IpingNativeIpPage> {
  String _query = '';
  var _tab = _NativeIpTab.buy;
  String? _continent;
  final _selectedTags = <String>{};

  void _search(String query) => setState(() => _query = query);

  void _toggleTag(String key) {
    setState(() {
      if (!_selectedTags.add(key)) _selectedTags.remove(key);
    });
  }

  Future<void> _buy(NativeIpOffer offer, List<TunnelPlan> plans) async {
    if (offer.stock < 1) return;
    final l = context.appLocalizations;
    final order = await showIpingNativeIpPurchase(
      context,
      offer: offer,
      plans: plans,
    );
    if (order == null || !mounted) return;
    final message = order.tunnelIds.isEmpty
        ? l.ipingNativeIpPurchased
        : offer.line == NativeIpLine.b
        ? l.ipingNativeIpPurchasedWithTunnel
        : l.ipingNativeIpPurchasedTunnelLater;
    dialogs.showNotifier(message);
  }

  bool _shows(
    NativeIpOffer offer,
    AppLocalizations l, {
    required String query,
    required String? continent,
    required Set<String> tagKeys,
  }) {
    if (continent != null &&
        continentOfCountryCode(offer.countryCode) != continent) {
      return false;
    }
    if (tagKeys.isNotEmpty) {
      final keys = {for (final tag in offer.tags) tag.key};
      if (!tagKeys.every(keys.contains)) return false;
    }
    if (query.isEmpty) return true;
    return [
      offer.country,
      offer.cityName,
      offer.countryCode,
      offer.line.name,
      nativeIpLineLabel(l, offer.line),
      for (final tag in offer.tags) tag.label,
    ].any((part) => part.toLowerCase().contains(query));
  }

  List<NativeIpOffer> _visible(
    List<NativeIpOffer> offers,
    AppLocalizations l, {
    required String? continent,
    required Set<String> tagKeys,
  }) {
    final query = _query.trim().toLowerCase();
    return [
      for (final offer in offers)
        if (_shows(
          offer,
          l,
          query: query,
          continent: continent,
          tagKeys: tagKeys,
        ))
          offer,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final owned = _tab == _NativeIpTab.owned;
    final inventory = ref.watch(ipingNativeIpInventoryProvider);
    final plans = ref.watch(ipingTunnelPlansProvider);
    final ownedLoading = owned && ref.watch(ipingUserProxiesProvider).isLoading;
    final offers = inventory.value;
    final continents = offers == null
        ? const <String>[]
        : nativeIpContinentsOf(offers.map((offer) => offer.countryCode));
    final continent = continents.contains(_continent) ? _continent : null;
    final filterTags = offers == null
        ? const <NativeIpTag>[]
        : _filterTags(offers);
    final selectedTags = {
      for (final key in _selectedTags)
        if (filterTags.any((tag) => tag.key == key)) key,
    };
    final visible = offers == null
        ? const <NativeIpOffer>[]
        : _visible(offers, l, continent: continent, tagKeys: selectedTags);
    final searching = _query.trim().isNotEmpty;
    final failed = offers == null && inventory.hasError;
    final filtered =
        offers != null && offers.isNotEmpty && selectedTags.isNotEmpty;
    final error = inventory.error;
    final showFilters = !owned && offers != null && offers.isNotEmpty;
    final loading = owned
        ? ownedLoading
        : inventory.isLoading || plans.isLoading;
    return CommonScaffold(
      title: l.ipingNativeIp,
      isLoading: loading,
      searchState: AppBarSearchState(
        onSearch: _search,
        query: searching ? _query : null,
      ),
      primaryAction: IconButtonData(
        glyph: AppGlyphs.refresh,
        tooltip: l.retry,
        isLoading: owned ? ownedLoading : inventory.isLoading,
        onPressed: owned
            ? ownedLoading
                  ? null
                  : () => ref.invalidate(ipingUserProxiesProvider)
            : inventory.isLoading
            ? null
            : () {
                ref.invalidate(ipingNativeIpInventoryProvider);
                ref.invalidate(ipingTunnelPlansProvider);
              },
      ),
      body: AppBarClearance(
        child: Builder(
          builder: (context) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: SegmentedControl(
                  segments: [
                    (_NativeIpTab.buy, l.ipingNativeIpBuy),
                    (_NativeIpTab.owned, l.ipingNativeIpOwned),
                  ],
                  value: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
              if (owned)
                Expanded(child: IpingOwnedNativeIps(query: _query))
              else ...[
                if (showFilters)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _NativeIpFilters(
                      continents: continents,
                      continent: continent,
                      tags: filterTags,
                      selectedTags: selectedTags,
                      resultCount: visible.length,
                      onContinent: (value) =>
                          setState(() => _continent = value),
                      onTag: _toggleTag,
                      onClearTags: () => setState(_selectedTags.clear),
                    ),
                  ),
                if (plans.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: ErrorBanner(message: l.ipingNativeIpPlansFailed),
                  ),
                Expanded(
                  child: NullStatusSwitcher(
                    isLoading: inventory.isLoading && offers == null,
                    isEmpty: visible.isEmpty,
                    isSearching: searching && !failed,
                    nullStatus: NullStatus(
                      illustration: failed
                          ? NullStatusIllustration.error
                          : filtered
                          ? NullStatusIllustration.search
                          : NullStatusIllustration.data,
                      label: failed
                          ? error is IpingException &&
                                    error.failure == IpingFailure.session
                                ? l.ipingSessionExpired
                                : l.ipingNativeIpLoadFailed
                          : filtered
                          ? l.ipingNativeIpFilteredEmpty
                          : l.ipingNativeIpEmpty,
                      action: failed
                          ? TextButton(
                              onPressed: () => ref.invalidate(
                                ipingNativeIpInventoryProvider,
                              ),
                              child: Text(l.retry),
                            )
                          : filtered
                          ? TextButton(
                              onPressed: () => setState(_selectedTags.clear),
                              child: Text(
                                l.ipingNativeIpClearTags(selectedTags.length),
                              ),
                            )
                          : null,
                    ),
                    child: WidthBuilder(
                      builder: (context, width) {
                        final columns = width >= 640 ? 2 : 1;
                        final rowCount = (visible.length / columns).ceil();
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24 + BottomInsetScope.of(context),
                          ),
                          itemCount: rowCount,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: ipingCardGap),
                          itemBuilder: (context, rowIndex) {
                            if (columns == 1) {
                              final offer = visible[rowIndex];
                              return _NativeIpOfferCard(
                                offer: offer,
                                onBuy: offer.stock < 1
                                    ? null
                                    : () =>
                                          _buy(offer, plans.value ?? const []),
                              );
                            }
                            final first = rowIndex * 2;
                            final second = first + 1;
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _NativeIpOfferCard(
                                      offer: visible[first],
                                      onBuy: visible[first].stock < 1
                                          ? null
                                          : () => _buy(
                                              visible[first],
                                              plans.value ?? const [],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: ipingCardGap),
                                  Expanded(
                                    child: second < visible.length
                                        ? _NativeIpOfferCard(
                                            offer: visible[second],
                                            onBuy: visible[second].stock < 1
                                                ? null
                                                : () => _buy(
                                                    visible[second],
                                                    plans.value ?? const [],
                                                  ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NativeIpFilters extends StatelessWidget {
  const _NativeIpFilters({
    required this.continents,
    required this.continent,
    required this.tags,
    required this.selectedTags,
    required this.resultCount,
    required this.onContinent,
    required this.onTag,
    required this.onClearTags,
  });

  final List<String> continents;
  final String? continent;
  final List<NativeIpTag> tags;
  final Set<String> selectedTags;
  final int resultCount;
  final ValueChanged<String?> onContinent;
  final ValueChanged<String> onTag;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final caption = AppTextStyle.footnote
        .of(context, emphasized: true)
        .copyWith(color: context.colorScheme.onSurface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        if (continents.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              IpingPill(
                key: const ValueKey('native-ip-filter-continent-all'),
                label: l.ipingNativeIpAll,
                selected: continent == null,
                onPressed: () => onContinent(null),
              ),
              for (final code in continents)
                IpingPill(
                  key: ValueKey('native-ip-filter-continent-$code'),
                  label: _continentLabel(l, code),
                  selected: continent == code,
                  onPressed: () => onContinent(code),
                ),
            ],
          ),
        if (tags.isNotEmpty) ...[
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Text(l.ipingNativeIpTags, style: caption),
                const SizedBox(width: 8),
                Text(l.ipingNativeIpTagsHint, style: context.listCaptionStyle),
                const Spacer(),
                if (selectedTags.isNotEmpty)
                  InkWell(
                    key: const ValueKey('native-ip-clear-tags'),
                    customBorder: AppShape.sm,
                    onTap: onClearTags,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        l.ipingNativeIpClearTags(selectedTags.length),
                        style: AppTextStyle.caption1
                            .of(context, emphasized: true)
                            .copyWith(color: context.colorScheme.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                IpingPill(
                  key: ValueKey('native-ip-filter-tag-${tag.key}'),
                  label: tag.label,
                  selected: selectedTags.contains(tag.key),
                  color: _tagColors(context, tag.tone).$1,
                  foregroundColor: _tagColors(context, tag.tone).$2,
                  onPressed: () => onTag(tag.key),
                ),
            ],
          ),
        ],
        Text(
          l.ipingNativeIpResultCount(resultCount),
          style: context.listCaptionStyle,
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final (label, color, foreground) = stock < 1
        ? (
            l.ipingNativeIpSoldOut,
            scheme.errorContainer,
            scheme.onErrorContainer,
          )
        : stock <= _lowStock
        ? (
            l.ipingNativeIpStock(stock),
            scheme.warningContainer,
            scheme.onWarningContainer,
          )
        : (
            l.ipingNativeIpStock(stock),
            context.raisedSurfaceLevel.colorOf(scheme),
            scheme.onSurfaceVariant,
          );
    return TonalChip(label: label, color: color, foregroundColor: foreground);
  }
}

class _MonthlyPrice extends StatelessWidget {
  const _MonthlyPrice({required this.price, required this.inStock});

  final double price;
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final amount = ipingCurrency(price);
    final text = context.appLocalizations.ipingNativeIpMonthly(amount);
    final at = text.indexOf(amount);
    final amountStyle = AppTextStyle.title3
        .of(context, emphasized: true)
        .toTabular
        .copyWith(color: inStock ? scheme.onSurface : scheme.onSurfaceVariant);
    if (at < 0) return Text(text, style: amountStyle);
    return Text.rich(
      TextSpan(
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: scheme.onSurfaceVariant),
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(text: amount, style: amountStyle),
          TextSpan(text: text.substring(at + amount.length)),
        ],
      ),
    );
  }
}

class _NativeIpOfferCard extends StatelessWidget {
  const _NativeIpOfferCard({required this.offer, required this.onBuy});

  final NativeIpOffer offer;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final inStock = offer.stock > 0;
    final flag = countryFlagEmoji(offer.countryCode);
    return CommonCard(
      radius: ipingCardCorner,
      onPressed: onBuy,
      padding: ipingCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IpingCardMark(
                    child: flag == null
                        ? Text(
                            offer.countryCode.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.caption1
                                .of(context, emphasized: true)
                                .copyWith(color: scheme.onSurfaceVariant),
                          )
                        : EmojiText(
                            flag,
                            style: AppTextStyle.title2.of(context),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      offer.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.headline.of(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StockBadge(stock: offer.stock),
                ],
              ),
              if (offer.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in offer.tags)
                      TonalChip(
                        label: tag.label,
                        color: _tagColors(context, tag.tone).$1,
                        foregroundColor: _tagColors(context, tag.tone).$2,
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MonthlyPrice(price: offer.price, inStock: inStock),
              if (inStock) const GlyphIcon(AppGlyphs.chevronForward),
            ],
          ),
        ],
      ),
    );
  }
}
