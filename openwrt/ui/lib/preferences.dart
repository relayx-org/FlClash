import 'package:fl_clash/ui/appearance.dart';
import 'package:fl_clash/ui/appearance_defaults.dart';
import 'package:fl_clash/ui/color.dart';
import 'package:fl_clash/ui/proxy_style.dart';
import 'package:material_ui/material_ui.dart';

T _enum<T extends Enum>(Iterable<T> values, Object? name, T fallback) =>
    values.where((value) => value.name == name).firstOrNull ?? fallback;

class RouterPreferences {
  RouterPreferences();
  ThemeMode themeMode = ThemeMode.system;
  String? locale;
  LiquidGlassMode glass = LiquidGlassMode.none;
  int? primaryColor = defaultPrimaryColor;
  List<int> primaryColors = defaultPrimaryColors;
  ColorStyle colorStyle = ColorStyle.vivid;
  bool pureBlack = false;
  bool floatingBar = true;
  TabAnimation animation = TabAnimation.slide;
  bool customTextScale = false;
  double textScale = 1;
  String? fontFamily;
  ProxyViewPreferences proxies = const ProxyViewPreferences();
  String testUrl = 'https://www.gstatic.com/generate_204';
  bool closeConnections = true;
  bool openLogs = false;
  bool hideIp = false;
  List<String> serviceOrder = [];
  List<String> disabledServices = [];

  factory RouterPreferences.fromJson(Map<String, Object?> json) {
    final value = RouterPreferences();
    value.themeMode = _enum(
      ThemeMode.values,
      json['themeMode'],
      value.themeMode,
    );
    value.locale = json['locale'] is String ? json['locale'] as String : null;
    value.glass = _enum(LiquidGlassMode.values, json['glass'], value.glass);
    if (json.containsKey('primaryColor')) {
      value.primaryColor = json['primaryColor'] is int
          ? json['primaryColor'] as int
          : null;
    }
    if (json['primaryColors'] case final List colors) {
      final valid = colors
          .whereType<int>()
          .where((color) => color >= 0 && color <= 0xffffffff)
          .take(64)
          .toList();
      if (valid.isNotEmpty) value.primaryColors = valid;
    }
    value.colorStyle = _enum(
      ColorStyle.values,
      json['colorStyle'],
      value.colorStyle,
    );
    value.pureBlack = json['pureBlack'] == true;
    value.floatingBar = json['floatingBar'] != false;
    value.animation = _enum(
      TabAnimation.values,
      json['animation'],
      value.animation,
    );
    value.customTextScale = json['customTextScale'] == true;
    if (json['textScale'] case final num scale when scale.isFinite) {
      value.textScale = scale.clamp(minTextScale, maxTextScale).toDouble();
    }
    value.fontFamily = json['fontFamily'] == 'packages/fl_clash/JetBrainsMono'
        ? json['fontFamily'] as String
        : null;
    final proxies = json['proxies'];
    if (proxies is Map) {
      value.proxies = ProxyViewPreferences(
        type: _enum(ProxiesType.values, proxies['type'], value.proxies.type),
        layout: _enum(
          ProxiesLayout.values,
          proxies['layout'],
          value.proxies.layout,
        ),
        card: _enum(ProxyCardType.values, proxies['card'], value.proxies.card),
        icon: _enum(
          ProxiesIconStyle.values,
          proxies['icon'],
          value.proxies.icon,
        ),
        sort: _enum(
          ProxiesSortType.values,
          proxies['sort'],
          value.proxies.sort,
        ),
        hideTimeout: proxies['hideTimeout'] == true,
      );
    }
    if (json['testUrl'] case final String url) {
      final parsed = Uri.tryParse(url);
      if (parsed != null &&
          const ['http', 'https'].contains(parsed.scheme) &&
          parsed.host.isNotEmpty &&
          parsed.userInfo.isEmpty) {
        value.testUrl = url;
      }
    }
    value.closeConnections = json['closeConnections'] != false;
    value.openLogs = json['openLogs'] == true;
    value.hideIp = json['hideIp'] == true;
    value.serviceOrder =
        (json['serviceOrder'] as List?)?.whereType<String>().toList() ?? [];
    value.disabledServices =
        (json['disabledServices'] as List?)?.whereType<String>().toList() ?? [];
    return value;
  }

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'locale': locale,
    'glass': glass.name,
    'primaryColor': primaryColor,
    'primaryColors': primaryColors,
    'colorStyle': colorStyle.name,
    'pureBlack': pureBlack,
    'floatingBar': floatingBar,
    'animation': animation.name,
    'customTextScale': customTextScale,
    'textScale': textScale,
    'fontFamily': fontFamily,
    'testUrl': testUrl,
    'closeConnections': closeConnections,
    'openLogs': openLogs,
    'hideIp': hideIp,
    'serviceOrder': serviceOrder,
    'disabledServices': disabledServices,
    'proxies': {
      'type': proxies.type.name,
      'layout': proxies.layout.name,
      'card': proxies.card.name,
      'icon': proxies.icon.name,
      'sort': proxies.sort.name,
      'hideTimeout': proxies.hideTimeout,
    },
  };
}
