import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/core_settings_page.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/override.dart';
import 'package:fl_clash/views/config/tun.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show dirname, join;

typedef _VpnUpdate<T> = VpnProps Function(VpnProps state, T value);

typedef _NetworkUpdate<T> = NetworkProps Function(NetworkProps state, T value);

typedef _TunUpdate<T> =
    PatchClashConfig Function(PatchClashConfig state, T value);

ConfigWriter<T> _vpnWriter<T>(_VpnUpdate<T> update) {
  return (ref, value) => ref
      .read(vpnSettingProvider.notifier)
      .update((state) => update(state, value));
}

ConfigWriter<T> _networkWriter<T>(_NetworkUpdate<T> update) {
  return (ref, value) => ref
      .read(networkSettingProvider.notifier)
      .update((state) => update(state, value));
}

ConfigWriter<T> _tunWriter<T>(_TunUpdate<T> update) {
  return (ref, value) => ref
      .read(patchClashConfigProvider.notifier)
      .update((state) => update(state, value));
}

ConfigWriter<T> _settingWriter<T>(
  String key, {
  Object? Function(T value)? encode,
}) =>
    (ref, value) => globalState.safeRun(
      () => ref.read(ipingBackendProvider).updateSettings({
        key: encode == null ? value : encode(value),
      }),
    );

ConfigToggleItem _vpnToggle({
  required ConfigLabel title,
  required bool Function(VpnProps state) select,
  required _VpnUpdate<bool> update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: vpnSettingProvider.select(select),
    onChanged: _vpnWriter(update),
  );
}

ConfigToggleItem _networkToggle({
  required ConfigLabel title,
  required bool Function(NetworkProps state) select,
  required _NetworkUpdate<bool> update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: networkSettingProvider.select(select),
    onChanged: _networkWriter(update),
  );
}

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => 'VPN',
      select: (state) => state.enable,
      update: (state, value) => state.copyWith(enable: value),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigToggleItem(
      title: (l) => l.tun,
      selector: patchClashConfigProvider.select((state) => state.tun.enable),
      onChanged: _settingWriter('tun.enable'),
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.allowBypass,
      select: (state) => state.allowBypass,
      update: (state, value) => state.copyWith(allowBypass: value),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.systemProxy,
      select: (state) => state.systemProxy,
      update: (state, value) => state.copyWith(systemProxy: value),
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _networkToggle(
      title: (l) => l.systemProxy,
      select: (state) => state.systemProxy,
      update: (state, value) => state.copyWith(systemProxy: value),
    );
  }
}

class Ipv6Item extends ConsumerWidget {
  const Ipv6Item({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => 'IPv6',
      select: (state) => state.ipv6,
      update: (state, value) => state.copyWith(ipv6: value),
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _networkToggle(
      title: (l) => l.autoSetSystemDns,
      select: (state) => state.autoSetSystemDns,
      update: (state, value) => state.copyWith(autoSetSystemDns: value),
    );
  }
}

class DNSHijackingItem extends ConsumerWidget {
  const DNSHijackingItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _vpnToggle(
      title: (l) => l.dnsHijacking,
      select: (state) => state.dnsHijacking,
      update: (state, value) => state.copyWith(dnsHijacking: value),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<TunStack>(
      title: (l) => l.stackMode,
      options: TunStack.values,
      textBuilder: (stack) => stack.name,
      selector: patchClashConfigProvider.select((state) => state.tun.stack),
      onChanged: _settingWriter<TunStack>(
        'tun.stack',
        encode: (value) => value.name,
      ),
    );
  }
}

class InterfaceNameModeItem extends ConsumerWidget {
  const InterfaceNameModeItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    return ConfigOptionsItem<InterfaceNameMode>(
      title: (l) => l.interfaceNameMode,
      options: InterfaceNameMode.values,
      textBuilder: (mode) => switch (mode) {
        InterfaceNameMode.clear => appLocalizations.interfaceNameModeClear,
        InterfaceNameMode.follow => appLocalizations.interfaceNameModeFollow,
        InterfaceNameMode.custom => appLocalizations.interfaceNameModeCustom,
      },
      selector: patchClashConfigProvider.select(
        (state) => state.interfaceNameMode,
      ),
      onChanged: _tunWriter(
        (state, value) => state.copyWith(interfaceNameMode: value),
      ),
    );
  }
}

class InterfaceNameItem extends ConsumerWidget {
  const InterfaceNameItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.interfaceName,
      maxLength: TextInputLimits.name,
      selector: patchClashConfigProvider.select((state) => state.interfaceName),
      onChanged: _tunWriter(
        (state, value) => state.copyWith(interfaceName: value.trim()),
      ),
    );
  }
}

class BypassPrivateRouteItem extends ConsumerWidget {
  const BypassPrivateRouteItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return _networkToggle(
      title: (l) => l.bypassPrivateRoute,
      select: (state) => state.bypassPrivateRoute,
      update: (state, value) => state.copyWith(bypassPrivateRoute: value),
    );
  }
}

class BypassDomainItem extends ConsumerWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigListEditItem(
      title: (l) => l.bypassDomain,
      itemMaxLength: TextInputLimits.domain,
      selector: networkSettingProvider.select((state) => state.bypassDomain),
      onChanged: _networkWriter(
        (state, value) => state.copyWith(bypassDomain: value),
      ),
    );
  }
}

class RouteAddressItem extends ConsumerWidget {
  const RouteAddressItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigListEditItem(
      title: (l) => l.routeAddress,
      itemMaxLength: TextInputLimits.cidr,
      itemValidator: validateCidr,
      selector: patchClashConfigProvider.select(
        (state) => state.tun.routeAddress,
      ),
      onChanged: _settingWriter('tun.route-address'),
    );
  }
}

class LoopbackItem extends StatelessWidget {
  const LoopbackItem({super.key});

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(context.appLocalizations.loopback),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          '',
        );
      },
    );
  }
}

const _maxUint32 = 0xFFFFFFFF;

class _NumberItem extends ConsumerWidget {
  const _NumberItem({
    required this.title,
    required this.select,
    required this.update,
    this.isSeconds = false,
    this.min = 0,
    this.max = _maxUint32,
    this.setting,
  });

  final ConfigLabel title;
  final int Function(PatchClashConfig state) select;
  final _TunUpdate<int> update;
  final bool isSeconds;
  final int min;
  final int max;
  final String? setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final label = title(appLocalizations);
    final value = ref.watch(patchClashConfigProvider.select(select));
    return ListItem.input(
      title: Text(label),
      subtitle: Text(
        isSeconds ? appLocalizations.secondsCount(value) : '$value',
      ),
      dialogTitle: label,
      value: '$value',
      resetValue: '${select(defaultClashConfig)}',
      suffixText: isSeconds ? appLocalizations.seconds : null,
      maxLength: TextInputLimits.number,
      keyboardType: TextInputType.number,
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        if (number == null) {
          return appLocalizations.numberTip(label);
        }
        return number < min || number > max
            ? appLocalizations.numberRangeTip(label, '$min', '$max')
            : null;
      },
      onChanged: (value) {
        if (value == null) {
          return;
        }
        if (setting case final key?) {
          _settingWriter<int>(key)(ref, int.parse(value.trim()));
          return;
        }
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => update(state, int.parse(value.trim())));
      },
    );
  }
}

// Android's VPN service starts from these rows; the desktop TUN takes the
// same keys as overrides, so a profile's own values apply unless picked.
List<Widget> tunItems({required bool isMipsStack}) {
  return [
    _NumberItem(
      title: (l) => 'MTU',
      setting: 'tun.mtu',
      min: minTunMtu,
      max: maxTunMtu,
      select: (state) => state.tun.mtu,
      update: (state, value) => state.copyWith.tun(mtu: value),
    ),
    if (isMipsStack)
      ConfigOptionsItem<String>(
        title: (l) => l.congestionController,
        options: congestionControllers,
        textBuilder: (value) => value,
        selector: patchClashConfigProvider.select(
          (state) => state.tun.congestionController,
        ),
        onChanged: _settingWriter('tun.congestion-controller'),
      ),
    const BypassPrivateRouteItem(),
    const RouteAddressItem(),
    ConfigListEditItem(
      title: (l) => l.routeExcludeAddress,
      itemMaxLength: TextInputLimits.cidr,
      itemValidator: validateCidr,
      selector: patchClashConfigProvider.select(
        (state) => state.tun.routeExcludeAddress,
      ),
      onChanged: _settingWriter('tun.route-exclude-address'),
    ),
  ];
}

class TunSection extends ConsumerWidget {
  const TunSection({
    super.key,
    required this.isDesktop,
    required this.isLinux,
    required this.isWindows,
  });

  final bool isDesktop;
  final bool isLinux;
  final bool isWindows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    if (!isDesktop) {
      final isMipsStack = ref.watch(
        patchClashConfigProvider.select(
          (state) => state.tun.stack == TunStack.mips,
        ),
      );
      return generateSection(
        title: appLocalizations.tun,
        items: tunItems(isMipsStack: isMipsStack),
        footer: appLocalizations.bypassPrivateRouteDesc,
      );
    }
    final spec = appTunOverrideSpec(isLinux: isLinux, isWindows: isWindows);
    final picked = ref.watch(
      patchClashConfigProvider.select((state) => state.tunOverrideKeys),
    );
    final listed = [
      for (final key in spec.values)
        if (picked.contains(key)) key,
    ];
    void handleAdd() => showOverrideAddSheet(context, ref, spec);
    return generateAnimatedSection(
      title: appLocalizations.tun,
      items: [
        const BypassPrivateRouteItem(key: ValueKey(#bypassPrivateRoute)),
        for (final key in listed)
          OverrideEntry(key: ValueKey(key), spec: spec, overrideKey: key),
        if (listed.length < spec.values.length)
          FormRow(
            key: const ValueKey(#add),
            leading: EntryButton.add(onPressed: handleAdd),
            title: spec.target.addEntry(appLocalizations),
            titleStyle: TextStyle(color: context.colorScheme.primary),
            onPressed: handleAdd,
          ),
      ],
      footer: [
        appLocalizations.bypassPrivateRouteDesc,
        appLocalizations.tunOverrideDesc,
        ?spec.footerOf(listed, appLocalizations),
      ].join('\n'),
    );
  }
}

// mihomo keeps TCP keep-alive off on Android whatever the config says
// (component/keepalive), and only Linux honours a routing mark.
List<Widget> outboundItems({required bool isDesktop, required bool isLinux}) {
  return [
    if (isDesktop) ...[
      ConfigToggleItem(
        title: (l) => l.disableKeepAlive,
        selector: patchClashConfigProvider.select(
          (state) => state.disableKeepAlive,
        ),
        onChanged: _tunWriter(
          (state, value) => state.copyWith(disableKeepAlive: value),
        ),
      ),
      _NumberItem(
        title: (l) => l.keepAliveIdle,
        isSeconds: true,
        select: (state) => state.keepAliveIdle,
        update: (state, value) => state.copyWith(keepAliveIdle: value),
      ),
      _NumberItem(
        title: (l) => l.keepAliveIntervalDesc,
        isSeconds: true,
        select: (state) => state.keepAliveInterval,
        update: (state, value) => state.copyWith(keepAliveInterval: value),
      ),
    ],
    if (isLinux)
      _NumberItem(
        title: (l) => l.routingMark,
        select: (state) => state.routingMark,
        update: (state, value) => state.copyWith(routingMark: value),
      ),
  ];
}

List<Widget> networkOptionsItems({
  required bool isDesktop,
  required bool isMacOS,
  required bool isCustomInterfaceName,
}) {
  return [
    if (isDesktop) const TUNItem(),
    if (isMacOS) const AutoSetSystemDnsItem(),
    const TunStackItem(),
    // mihomo's DefaultSocketHook ignores interface-name on Android
    // (core/lib.go installHooks, vendored dialer.go), so these rows only
    // apply on desktop.
    if (isDesktop) ...[
      const InterfaceNameModeItem(),
      if (isCustomInterfaceName) const InterfaceNameItem(),
    ],
  ];
}

class VpnSections extends ConsumerWidget {
  const VpnSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final authenticationEnable = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    return Column(
      children: [
        generateSection(
          items: const [VPNItem()],
          footer: appLocalizations.vpnEnableDesc,
        ),
        generateSection(
          title: 'VPN',
          items: const [
            VpnSystemProxyItem(),
            BypassDomainItem(),
            AllowBypassItem(),
            Ipv6Item(),
            DNSHijackingItem(),
          ],
          footer: [
            if (authenticationEnable)
              appLocalizations.authenticationSystemProxyDesc,
            appLocalizations.bypassDomainDesc,
            appLocalizations.ipv6InboundDesc,
          ].join('\n'),
        ),
      ],
    );
  }
}

class SystemProxySection extends StatelessWidget {
  const SystemProxySection({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return generateSection(
      title: appLocalizations.system,
      items: [
        const SystemProxyItem(),
        const BypassDomainItem(),
        if (system.isWindows) const LoopbackItem(),
      ],
      footer: appLocalizations.bypassDomainDesc,
    );
  }
}

class NetworkOptionsSection extends ConsumerWidget {
  const NetworkOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomInterfaceName = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.interfaceNameMode == InterfaceNameMode.custom,
      ),
    );
    final appLocalizations = context.appLocalizations;
    final footer = [
      if (system.isDesktop) ...[
        appLocalizations.tunDesc,
        if (isCustomInterfaceName) appLocalizations.interfaceNameDesc,
      ],
    ];
    return generateSection(
      title: appLocalizations.options,
      items: networkOptionsItems(
        isDesktop: system.isDesktop,
        isMacOS: system.isMacOS,
        isCustomInterfaceName: isCustomInterfaceName,
      ),
      footer: footer.isEmpty ? null : footer.join('\n'),
    );
  }
}

class NetworkListView extends ConsumerWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCustomInterfaceName = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.interfaceNameMode == InterfaceNameMode.custom,
      ),
    );
    final excluded = <String>{
      if (!system.isDesktop) ...{
        'disable-keep-alive',
        'keep-alive-idle',
        'keep-alive-interval',
        'tun.enable',
        'tun.device',
        'tun.stack',
        'tun.mtu',
        'tun.congestion-controller',
        'tun.route-address',
        'tun.route-exclude-address',
      },
      if (!system.isLinux) ...{
        'routing-mark',
        'tun.gso',
        'tun.include-interface',
        'tun.exclude-interface',
        'tun.include-uid',
        'tun.exclude-uid',
        'tun.exclude-src-port',
        'tun.exclude-dst-port',
      },
      if (!system.isLinux && !system.isWindows) 'tun.strict-route',
    };
    return IpingCoreSettingsPage(
      backend: ref.watch(ipingBackendProvider),
      kind: IpingCoreSettingsKind.network,
      scaffold: false,
      excluded: excluded,
      before: [
        if (system.isAndroid) const VpnSections(),
        if (system.isDesktop) const SystemProxySection(),
        generateSection(
          title: context.appLocalizations.options,
          items: [
            if (system.isMacOS) const AutoSetSystemDnsItem(),
            if (system.isDesktop) ...[
              const InterfaceNameModeItem(),
              if (isCustomInterfaceName) const InterfaceNameItem(),
              const BypassPrivateRouteItem(),
            ],
          ],
          footer: context.appLocalizations.bypassPrivateRouteDesc,
        ),
      ],
      after: [
        if (!system.isDesktop) ...[
          const TunStackItem(),
          const TunSection(isDesktop: false, isLinux: false, isWindows: false),
        ],
      ],
      footer: system.isDesktop
          ? context.appLocalizations.tunOverrideDesc
          : null,
    );
  }
}
