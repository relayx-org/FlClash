enum ProxiesLayout { loose, standard, tight }

enum ProxyCardType { loose, standard, compact }

enum ProxiesIconStyle { filled, plain, hidden }

enum ProxiesType { tab, list }

enum ProxiesSortType { none, delay, name }

const defaultProxyViewType = ProxiesType.list;
const defaultProxyViewSort = ProxiesSortType.none;
const defaultProxyViewLayout = ProxiesLayout.standard;
const defaultProxyViewIcon = ProxiesIconStyle.filled;
const defaultProxyViewCard = ProxyCardType.standard;
const defaultProxyViewHideTimeout = false;

class ProxyViewPreferences {
  const ProxyViewPreferences({
    this.type = defaultProxyViewType,
    this.sort = defaultProxyViewSort,
    this.layout = defaultProxyViewLayout,
    this.icon = defaultProxyViewIcon,
    this.card = defaultProxyViewCard,
    this.hideTimeout = defaultProxyViewHideTimeout,
  });
  final ProxiesType type;
  final ProxiesSortType sort;
  final ProxiesLayout layout;
  final ProxiesIconStyle icon;
  final ProxyCardType card;
  final bool hideTimeout;
  ProxyViewPreferences copyWith({
    ProxiesType? type,
    ProxiesSortType? sort,
    ProxiesLayout? layout,
    ProxiesIconStyle? icon,
    ProxyCardType? card,
    bool? hideTimeout,
  }) => ProxyViewPreferences(
    type: type ?? this.type,
    sort: sort ?? this.sort,
    layout: layout ?? this.layout,
    icon: icon ?? this.icon,
    card: card ?? this.card,
    hideTimeout: hideTimeout ?? this.hideTimeout,
  );
}
