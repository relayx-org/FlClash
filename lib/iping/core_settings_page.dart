import 'dart:async';

import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/map_edit_view.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/config_value.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:material_ui/material_ui.dart';

import 'backend.dart';
import 'settings_error.dart';

enum IpingCoreSettingsKind { network, dns }

class IpingCoreSettingsPage extends StatefulWidget {
  const IpingCoreSettingsPage({
    super.key,
    required this.backend,
    required this.kind,
    this.before = const [],
    this.after = const [],
    this.excluded = const {},
    this.footer,
    this.scaffold = true,
    this.save,
  });
  final IpingBackend backend;
  final IpingCoreSettingsKind kind;
  final List<Widget> before;
  final List<Widget> after;
  final Set<String> excluded;
  final String? footer;
  final bool scaffold;
  final Future<void> Function(Map<String, Object?> changes)? save;
  @override
  State<IpingCoreSettingsPage> createState() => _IpingCoreSettingsPageState();
}

class _IpingCoreSettingsPageState extends State<IpingCoreSettingsPage> {
  IpingSettings? _values;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final values = await widget.backend.readSettings();
      if (mounted) {
        setState(() {
          _values = values;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _change(String key, Object? value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.save ?? widget.backend.updateSettings)({key: value});
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessage(Object error) =>
      ipingSettingsErrorMessage(error, AppLocalizations.of(context)) ??
      error.toString();
  Widget _overrideRow(String key, Widget child) {
    if (!_values!.values.containsKey(key) || widget.excluded.contains(key)) {
      return const SizedBox.shrink();
    }
    final overridden = _values?.overrides[key];
    if (overridden == null) return child;
    return ContextMenuRegion(
      menuItems: [
        CommonPopupMenuItem(
          glyph: AppGlyphs.reset,
          label: AppLocalizations.of(context).followProfile,
          checked: !overridden,
          onPressed: overridden && !_saving ? () => _change(key, null) : null,
        ),
      ],
      child: child,
    );
  }

  bool _bool(String key) => _values?.flag(key) ?? false;
  String _text(String key) => _values?.text(key) ?? '';
  List<String> _list(String key) => [
    for (final item in _values?[key] as List? ?? []) item.toString(),
  ];
  Map<String, String> _map(String key) => _values?.stringMap(key) ?? {};

  Widget _toggle(String key, String title) => _overrideRow(
    key,
    ConfigToggleValue(
      key: ValueKey(key),
      title: title,
      value: _bool(key),
      onChanged: (value) => _change(key, value),
    ),
  );
  Widget _options(String key, String title, [List<String>? options]) =>
      _overrideRow(
        key,
        ConfigOptionsValue<String>(
          key: ValueKey(key),
          title: title,
          value: _text(key),
          subtitle: Text(_text(key)),
          options: options ?? _values!.options(key),
          textBuilder: (value) => value,
          onChanged: (value) => _change(key, value),
        ),
      );
  Widget _input(
    String key,
    String title, {
    int? min,
    int? max,
    int length = TextInputLimits.domain,
  }) {
    final l = AppLocalizations.of(context);
    return _overrideRow(
      key,
      ConfigTextValue(
        key: ValueKey(key),
        title: title,
        value: _text(key),
        maxLength: length,
        keyboardType: min == null ? TextInputType.text : TextInputType.number,
        validator: (value) {
          if (value == null ||
              value.trim().isEmpty && key != 'dns.fake-ip-range6') {
            return l.emptyTip(title);
          }
          if (min != null) {
            final number = int.tryParse(value);
            if (number == null || number < min || number > max!) {
              return l.numberTip(title);
            }
          }
          try {
            _values!.validate({key: min == null ? value : int.parse(value)});
            return null;
          } on IpingSettingsException catch (error) {
            return _errorMessage(error);
          }
        },
        onChanged: (value) {
          if (value != null) {
            unawaited(_change(key, min == null ? value : int.parse(value)));
          }
        },
      ),
    );
  }

  Widget _listRow(
    String key,
    String title, {
    int length = TextInputLimits.dnsServer,
    bool integers = false,
  }) {
    final items = _list(key);
    final l = AppLocalizations.of(context);
    return _overrideRow(
      key,
      ListItem<List<String>>.open(
        key: ValueKey(key),
        title: Text(title),
        subtitle: Text(items.isEmpty ? l.none : l.itemsCount(items.length)),
        widget: ListEditView(
          title: title,
          items: items,
          titleBuilder: (value) => Text(value),
          itemMaxLength: length,
          itemValidator: (value) {
            try {
              _values!.validate({
                key: [integers ? int.parse(value) : value],
              });
              return null;
            } catch (_) {
              return _errorMessage(
                IpingSettingsException(key, IpingSettingsIssue.invalid),
              );
            }
          },
          multiline: key.startsWith('custom.') && key != 'custom.rules',
        ),
        onChanged: (value) {
          if (value is List<String>) {
            final parsed = integers
                ? [for (final item in value) int.tryParse(item)]
                : value;
            try {
              _values!.validate({key: parsed});
            } catch (error) {
              setState(() => _error = _errorMessage(error));
              return;
            }
            unawaited(_change(key, parsed));
          }
        },
      ),
    );
  }

  Widget _mapRow(String key, String title) {
    final values = _map(key);
    final l = AppLocalizations.of(context);
    return _overrideRow(
      key,
      ListItem<Map<String, String>>.open(
        key: ValueKey(key),
        title: Text(title),
        subtitle: Text(values.isEmpty ? l.none : l.itemsCount(values.length)),
        widget: MapEditView(
          title: title,
          entries: values,
          titleBuilder: (item) => Text(item.key),
          subtitleBuilder: (item) => Text(item.value),
          keyMaxLength: TextInputLimits.domain,
          valueMaxLength: 2048,
        ),
        onChanged: (value) {
          if (value is Map<String, String>) unawaited(_change(key, value));
        },
      ),
    );
  }

  Widget _section({String? title, required List<Widget> items}) {
    final visible = items.where((item) => item is! SizedBox).toList();
    return visible.isEmpty
        ? const SizedBox.shrink()
        : generateSection(title: title, items: visible);
  }

  Widget _network(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _sections(l.network, [
      _section(
        title: l.connection,
        items: [
          _toggle('disable-keep-alive', l.disableKeepAlive),
          _input('keep-alive-idle', l.keepAliveIdle, min: 1, max: 3600),
          _input('routing-mark', l.routingMark, min: 0, max: 0xFFFFFFFF),
          _input(
            'keep-alive-interval',
            l.keepAliveIntervalDesc,
            min: 1,
            max: 3600,
          ),
        ],
      ),
      _section(
        title: l.tun,
        items: [
          _toggle('tun.enable', l.status),
          _input('tun.device', 'Device'),
          _options('tun.stack', l.stackMode),
          _input('tun.mtu', 'MTU', min: 1280, max: 65535),
          _toggle('tun.gso', 'GSO'),
          _input('tun.gso-max-size', 'GSO Max Size', min: 1, max: 1048576),
          _listRow('tun.dns-hijack', l.dnsHijacking),
          _input('tun.congestion-controller', l.congestionController),
          _toggle('tun.strict-route', l.strictRoute),
          _listRow(
            'tun.route-address',
            l.routeAddress,
            length: TextInputLimits.cidr,
          ),
          _listRow(
            'tun.route-exclude-address',
            l.routeExcludeAddress,
            length: TextInputLimits.cidr,
          ),
          _input('tun.udp-timeout', l.udpTimeout, min: 1, max: 0xFFFFFFFF),
          _toggle('tun.disable-icmp-forwarding', l.disableIcmpForwarding),
          _listRow('tun.include-interface', l.includeInterface),
          _listRow('tun.exclude-interface', l.excludeInterface),
          _listRow('tun.include-uid', l.includeUid, integers: true),
          _listRow('tun.exclude-uid', l.excludeUid, integers: true),
          _listRow('tun.exclude-src-port', l.excludeSrcPort, integers: true),
          _listRow('tun.exclude-dst-port', l.excludeDstPort, integers: true),
        ],
      ),
    ]);
  }

  Widget _dns(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _sections('DNS', [
      _section(
        title: l.options,
        items: [
          _toggle('dns.enable', l.status),
          _input('dns.listen', l.listen),
          _input(
            'dns.listen-routing-mark',
            l.listenRoutingMark,
            min: 0,
            max: 0xFFFFFFFF,
          ),
          _toggle('dns.ipv6', 'IPv6'),
          _input('dns.ipv6-timeout', l.ipv6Timeout, min: 0, max: 10000),
          _toggle('dns.use-hosts', l.useHosts),
          _toggle('dns.use-system-hosts', l.useSystemHosts),
          _toggle('dns.respect-rules', l.respectRules),
          _toggle('dns.prefer-h3', 'Prefer H3'),
          _options('dns.cache-algorithm', l.cacheAlgorithm),
          _input('dns.cache-max-size', l.cacheMaxSize, min: 1, max: 1048576),
          _options('dns.enhanced-mode', l.dnsMode),
        ],
      ),
      _section(
        title: 'Fake-IP',
        items: [
          _input('dns.fake-ip-range', l.fakeipRange),
          _input('dns.fake-ip-range6', l.fakeipRange6),
          _input('dns.fake-ip-ttl', l.fakeipTtl, min: 1, max: 86400),
          _options('dns.fake-ip-filter-mode', l.fakeipFilterMode),
          _listRow('dns.fake-ip-filter', l.fakeipFilter),
        ],
      ),
      _section(
        title: 'Nameserver',
        items: [
          for (final entry in {
            'default-nameserver': 'Default Nameserver',
            'nameserver': 'Nameserver',
            'fallback': 'Fallback',
            'proxy-server-nameserver': 'Proxy Server Nameserver',
            'direct-nameserver': 'Direct Nameserver',
          }.entries)
            _listRow('dns.${entry.key}', entry.value),
          _mapRow('dns.nameserver-policy', 'Nameserver Policy'),
          _mapRow(
            'dns.proxy-server-nameserver-policy',
            'Proxy Server Nameserver Policy',
          ),
          _toggle(
            'dns.direct-nameserver-follow-policy',
            'Direct Nameserver Follow Policy',
          ),
          _toggle('dns.fallback-lazy-query', 'Fallback Lazy Query'),
        ],
      ),
      _section(
        title: l.fallbackFilter,
        items: [
          _toggle('dns.fallback-filter.geoip', 'GeoIP'),
          _input('dns.fallback-filter.geoip-code', 'GeoIP Code'),
          _listRow('dns.fallback-filter.geosite', 'GeoSite'),
          _listRow('dns.fallback-filter.ipcidr', 'IP-CIDR'),
          _listRow('dns.fallback-filter.domain', l.domain),
        ],
      ),
    ]);
  }

  Widget _sections(String title, List<Widget> children) {
    final body = Builder(
      builder: (context) => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        children: [
          ErrorBanner(message: _error),
          ...widget.before,
          ...children,
          ...widget.after,
          if (widget.footer != null) ListFooter(text: widget.footer!),
        ],
      ),
    );
    return widget.scaffold ? BaseScaffold(title: title, body: body) : body;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_values == null) {
      final body = NullStatusSwitcher(
        isLoading: _error == null,
        child: NullStatus(
          label: _error,
          action: TextButton(
            onPressed: () {
              setState(() => _error = null);
              unawaited(_load());
            },
            child: Text(l.retry),
          ),
        ),
      );
      return widget.scaffold
          ? BaseScaffold(
              title: widget.kind == IpingCoreSettingsKind.dns
                  ? 'DNS'
                  : l.network,
              body: body,
            )
          : body;
    }
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: widget.kind == IpingCoreSettingsKind.dns
              ? _dns(context)
              : _network(context),
        ),
        if (_saving) const Center(child: CommonCircleLoading()),
      ],
    );
  }
}
