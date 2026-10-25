import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/icons/icons.dart';
import '../../ui/ui.dart';
import '../../ui/proxy_style.dart';

class ProxiesPage extends StatelessWidget {
  const ProxiesPage({
    super.key,
    required this.body,
    required this.tabMode,
    required this.onSearch,
    required this.onTest,
    required this.onLocate,
    required this.onSettings,
    this.testing = false,
    this.loading = false,
    this.picker = false,
  });
  final Widget body;
  final bool tabMode;
  final bool testing;
  final bool loading;
  final bool picker;
  final ValueChanged<String> onSearch;
  final VoidCallback? onTest;
  final VoidCallback? onLocate;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primary = tabMode
        ? IconButtonData(
            glyph: AppGlyphs.bolt,
            tooltip: l.delayTest,
            isLoading: testing,
            onPressed: onTest,
          )
        : null;
    return CommonScaffold(
      isLoading: loading,
      resizeToAvoidBottomInset: false,
      primaryAction: primary,
      searchActions: [?primary],
      iconActions: [
        if (tabMode && !picker)
          IconButtonData(
            glyph: AppGlyphs.locate,
            tooltip: l.scrollToSelected,
            onPressed: onLocate,
          ),
      ],
      menuItems: picker
          ? const []
          : [
              CommonPopupMenuItem(
                glyph: AppGlyphs.sliders,
                label: l.settings,
                onPressed: onSettings,
              ),
            ],
      title: l.proxies,
      searchState: AppBarSearchState(onSearch: onSearch),
      body: body,
    );
  }
}

class ProxiesSettingsBody extends StatelessWidget {
  const ProxiesSettingsBody({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ProxyViewPreferences value;
  final ValueChanged<ProxyViewPreferences> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: context.contentTopPadding, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          generateSection(
            items: [
              ListItem<ProxiesType>.options(
                title: Text(l.style),
                options: ProxiesType.values,
                textBuilder: (type) =>
                    type == ProxiesType.list ? l.list : l.tab,
                value: value.type,
                onChanged: (type) => onChanged(value.copyWith(type: type)),
              ),
              ListItem<ProxiesSortType>.options(
                title: Text(l.sort),
                options: ProxiesSortType.values,
                textBuilder: (sort) => switch (sort) {
                  ProxiesSortType.none => l.defaultText,
                  ProxiesSortType.delay => l.delay,
                  ProxiesSortType.name => l.name,
                },
                value: value.sort,
                onChanged: (sort) => onChanged(value.copyWith(sort: sort)),
              ),
              ListItem<ProxiesLayout>.options(
                title: Text(l.layout),
                options: ProxiesLayout.values,
                textBuilder: (layout) => switch (layout) {
                  ProxiesLayout.tight => l.tight,
                  ProxiesLayout.standard => l.standard,
                  ProxiesLayout.loose => l.loose,
                },
                value: value.layout,
                onChanged: (layout) =>
                    onChanged(value.copyWith(layout: layout)),
              ),
              ListItem<ProxyCardType>.options(
                title: Text(l.size),
                options: ProxyCardType.values,
                textBuilder: (card) => switch (card) {
                  ProxyCardType.compact => l.compact,
                  ProxyCardType.standard => l.standard,
                  ProxyCardType.loose => l.loose,
                },
                value: value.card,
                onChanged: (card) => onChanged(value.copyWith(card: card)),
              ),
              if (value.type == ProxiesType.list)
                ListItem<ProxiesIconStyle>.options(
                  title: Text(l.iconStyle),
                  options: ProxiesIconStyle.values,
                  textBuilder: (icon) => switch (icon) {
                    ProxiesIconStyle.filled => l.iconStyleFilled,
                    ProxiesIconStyle.plain => l.iconStylePlain,
                    ProxiesIconStyle.hidden => l.iconStyleHidden,
                  },
                  value: value.icon,
                  onChanged: (icon) => onChanged(value.copyWith(icon: icon)),
                ),
            ],
          ),
          generateSection(
            title: l.filter,
            footer: l.hideTimeoutProxiesDesc,
            items: [
              ListItem.toggle(
                title: Text(l.hideTimeoutProxies),
                value: value.hideTimeout,
                onChanged: (hide) =>
                    onChanged(value.copyWith(hideTimeout: hide)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProxyTabsLayout extends StatelessWidget {
  const ProxyTabsLayout({
    super.key,
    required this.controller,
    required this.groups,
    required this.pages,
    this.groupTabs,
  });
  final TabController controller;
  final List<String> groups;
  final List<Widget> pages;
  final Widget? groupTabs;
  @override
  Widget build(BuildContext context) => AppBarClearance(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child:
              groupTabs ??
              ProxyGroupTabs(
                controller: controller,
                groups: groups,
                tooltip: AppLocalizations.of(context).proxyGroup,
              ),
        ),
        Expanded(
          child: TabBarView(controller: controller, children: pages),
        ),
      ],
    ),
  );
}

class ProxyCardsGrid extends StatelessWidget {
  const ProxyCardsGrid({
    super.key,
    this.storageKey,
    required this.controller,
    required this.columns,
    required this.itemHeight,
    required this.count,
    required this.itemBuilder,
  });
  final Key? storageKey;
  final ScrollController controller;
  final int columns;
  final double itemHeight;
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  @override
  Widget build(BuildContext context) => CommonScrollBar(
    controller: controller,
    thumbVisibility: true,
    child: GridView.builder(
      key: storageKey,
      controller: controller,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + BottomInsetScope.of(context),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: itemHeight,
      ),
      itemCount: count,
      addAutomaticKeepAlives: false,
      itemBuilder: itemBuilder,
    ),
  );
}

class ProxyNodePending extends StatelessWidget {
  const ProxyNodePending({super.key, this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: error == null
        ? const CommonCircleLoading(size: 18)
        : TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
  );
}
