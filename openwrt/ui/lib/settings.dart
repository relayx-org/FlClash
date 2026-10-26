import 'package:fl_clash/iping/core_settings_page.dart';
import 'package:fl_clash/iping/rules_page.dart';
import 'package:fl_clash/iping/scripts_page.dart';
import 'package:fl_clash/iping/profile_resources_page.dart';
import 'dart:async';

import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/features/form/map_edit_view.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/filters_page.dart';
import 'package:fl_clash/iping/resource_page.dart';
import 'package:fl_clash/iping/rule_provider_form.dart';
import 'package:fl_clash/iping/custom_proxy_form.dart';
import 'package:fl_clash/common/snowflake.dart';
import 'package:fl_clash/iping/settings_error.dart';
import 'package:fl_clash/ui/config_value.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/config/advanced_page.dart';
import 'package:fl_clash/views/config/custom_resources_page.dart';
import 'package:fl_clash/views/config/general_page.dart';
import 'package:fl_clash/views/config/port_form.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

enum RouterSettingsKind { general, network, dns, groupIcons }

class RouterAdvanced extends StatelessWidget {
  const RouterAdvanced({super.key});
  @override
  Widget build(BuildContext context) => const AdvancedSettingsPage(
    network: RouterCoreSettings(kind: RouterSettingsKind.network),
    dns: RouterCoreSettings(kind: RouterSettingsKind.dns),
    rules: _RouterRules(),
    scripts: _RouterScripts(),
  );
}

class RouterCustomResources extends StatelessWidget {
  const RouterCustomResources({super.key});
  @override
  Widget build(BuildContext context) {
    final backend = RouterScope.read(context).backend;
    final kinds = backend.resourceKinds;
    return CustomResourcesSettingsPage(
      application: IpingProfileResourcesPage(backend: backend),
      proxies: kinds.contains(IpingResourceKind.proxies)
          ? IpingResourcePage<IpingCustomProxy, String>(
              title: AppLocalizations.of(context).proxies,
              description: AppLocalizations.of(context).resourceLibraryHint,
              store: backend.customProxies,
              keyOf: (item) => item.id,
              nameOf: (item) => item.name,
              subtitleOf: (item) => item.type,
              editor: (context, item, controller) => IpingCustomProxyForm(
                proxy:
                    item ??
                    IpingCustomProxy(
                      id: uniqueId,
                      definition: const {'type': 'ss'},
                    ),
                isNew: item == null,
                controller: controller,
              ),
            )
          : null,
      providers: kinds.contains(IpingResourceKind.ruleProviders)
          ? IpingResourcePage<IpingRuleProvider, String>(
              title: AppLocalizations.of(context).ruleProviders,
              description: AppLocalizations.of(context).resourceLibraryHint,
              store: backend.ruleProviders,
              keyOf: (item) => item.id,
              nameOf: (item) => item.label,
              subtitleOf: (item) => '${item.behavior} · ${item.format}',
              editor: (context, item, controller) => IpingRuleProviderForm(
                provider: item ?? IpingRuleProvider(id: uniqueId, label: ''),
                editFormat: true,
                reservedLabels: {
                  for (final value in controller.items ?? <IpingRuleProvider>[])
                    if (value.id != item?.id) value.label,
                },
                save: (value) => controller.put(value, replacing: item?.id),
                errorOf: () => controller.error,
              ),
            )
          : null,
      filters: kinds.contains(IpingResourceKind.filters)
          ? IpingFiltersPage(
              store: backend.filters,
              description: AppLocalizations.of(context).resourceLibraryHint,
            )
          : null,
      groupIcons: kinds.contains(IpingResourceKind.groupIcons)
          ? const RouterCoreSettings(kind: RouterSettingsKind.groupIcons)
          : null,
    );
  }
}

class RouterCoreSettings extends StatefulWidget {
  const RouterCoreSettings({super.key, required this.kind});
  final RouterSettingsKind kind;
  @override
  State<RouterCoreSettings> createState() => _RouterCoreSettingsState();
}

class _RouterCoreSettingsState extends State<RouterCoreSettings> {
  IpingSettings? _values;
  bool _started = false;
  bool _saving = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.kind != RouterSettingsKind.network &&
          widget.kind != RouterSettingsKind.dns) {
        unawaited(_load());
      }
    }
  }

  Future<void> _load() async {
    try {
      final result = await RouterScope.read(context).backend.readSettings();
      if (mounted) {
        setState(() {
          _values = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _save(Map<String, Object?> changes) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RouterScope.read(context).saveSettings(changes);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
      rethrow;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _change(String key, Object? value) async {
    try {
      await _save({key: value});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  String _errorMessage(Object error) =>
      ipingSettingsErrorMessage(error, AppLocalizations.of(context)) ??
      error.toString();

  Widget _overrideRow(String key, Widget child) {
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
          if (value == null || value.trim().isEmpty) return l.emptyTip(title);
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
          multiline: key.startsWith('custom.') && key != 'custom.rules',
        ),
        onChanged: (value) {
          if (value is List<String>) unawaited(_change(key, value));
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

  Widget _general(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = RouterAppState.of(context);
    int port(String key) => (_values?[key] as num?)?.toInt() ?? 0;
    return GeneralSettingsPage(
      notices: [ErrorBanner(message: _error)],
      requestsFooter: l.routerSettingsHint,
      requests: [
        ConfigTextValue(
          title: l.testUrl,
          value: app.preferences.testUrl,
          maxLength: TextInputLimits.url,
          resetValue: 'https://www.gstatic.com/generate_204',
          validator: (value) {
            final uri = Uri.tryParse(value ?? '');
            return uri != null &&
                    const ['http', 'https'].contains(uri.scheme) &&
                    uri.host.isNotEmpty &&
                    uri.userInfo.isEmpty &&
                    uri.fragment.isEmpty
                ? null
                : l.urlTip(l.testUrl);
          },
          onChanged: (value) {
            if (value != null) {
              app.updatePreferences((prefs) => prefs.testUrl = value);
            }
          },
        ),
        _input('global-ua', l.userAgent, length: TextInputLimits.url),
      ],
      inbound: [
        ListItem(
          title: Text(l.port),
          subtitle: Text(_text('mixed-port')),
          onTap: () => showFormSheet<void>(
            context: context,
            builder: (_) => PortSettingsForm(
              value: (
                mixed: port('mixed-port'),
                http: port('port'),
                socks: port('socks-port'),
                redir: port('redir-port'),
                tproxy: port('tproxy-port'),
              ),
              defaults: (
                mixed: 7890,
                http: 0,
                socks: 0,
                redir: port('redir-port'),
                tproxy: port('tproxy-port'),
              ),
              onSave: (ports) => _save({
                'mixed-port': ports.mixed,
                'port': ports.http,
                'socks-port': ports.socks,
                'redir-port': ports.redir,
                'tproxy-port': ports.tproxy,
              }),
            ),
          ),
        ),
        _toggle('allow-lan', l.allowLan),
        _mapRow('hosts', 'Hosts'),
        _listRow('authentication', l.authentication, length: 2048),
      ],
      inboundFooter: l.authenticationDesc,
      connection: [
        ConfigToggleValue(
          title: l.autoCloseConnections,
          value: app.preferences.closeConnections,
          onChanged: (value) =>
              app.updatePreferences((prefs) => prefs.closeConnections = value),
        ),
      ],
      core: [
        _toggle('ipv6', 'IPv6'),
        _toggle('unified-delay', l.unifiedDelay),
        _toggle('tcp-concurrent', l.tcpConcurrent),
        _options('find-process-mode', l.findProcessMode),
        _options('geodata-loader', l.geodataLoader),
      ],
      logs: [
        _options('log-level', l.logLevel),
        ConfigToggleValue(
          title: l.logcat,
          value: app.preferences.openLogs,
          onChanged: (value) =>
              app.updatePreferences((prefs) => prefs.openLogs = value),
        ),
      ],
    );
  }

  Widget _sections(String title, List<Widget> children) => BaseScaffold(
    title: title,
    body: Builder(
      builder: (context) => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.contentTopPadding, bottom: 16),
        children: [
          ErrorBanner(message: _error),
          ...children,
          ListFooter(text: AppLocalizations.of(context).routerSettingsHint),
        ],
      ),
    ),
  );

  Widget _resources(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, row) = switch (widget.kind) {
      _ => (l.groupIcons, _mapRow('custom.icons', l.groupIcons)),
    };
    return _sections(title, [
      generateSection(
        items: [row],
        footer: widget.kind == RouterSettingsKind.groupIcons
            ? l.routerIconsHint
            : l.routerResourcesHint,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (widget.kind == RouterSettingsKind.network ||
        widget.kind == RouterSettingsKind.dns) {
      return IpingCoreSettingsPage(
        backend: RouterScope.read(context).backend,
        kind: widget.kind == RouterSettingsKind.dns
            ? IpingCoreSettingsKind.dns
            : IpingCoreSettingsKind.network,
        footer: l.routerSettingsHint,
        save: RouterScope.read(context).saveSettings,
      );
    }
    if (_values == null) {
      return BaseScaffold(
        title: l.settings,
        body: NullStatusSwitcher(
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
        ),
      );
    }
    final page = switch (widget.kind) {
      RouterSettingsKind.general => _general(context),

      _ => _resources(context),
    };
    return Stack(
      children: [
        AbsorbPointer(absorbing: _saving, child: page),
        if (_saving) const Center(child: CommonCircleLoading()),
      ],
    );
  }
}

class _RouterRules extends StatelessWidget {
  const _RouterRules();
  @override
  Widget build(BuildContext context) =>
      IpingAddedRulesPage(store: RouterScope.read(context).backend.addedRules);
}

class _RouterScripts extends StatelessWidget {
  const _RouterScripts();
  @override
  Widget build(BuildContext context) =>
      IpingScriptsPage(store: RouterScope.read(context).backend.scripts);
}
