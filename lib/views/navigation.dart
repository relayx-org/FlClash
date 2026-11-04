import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/page_destination.dart';

import '../pages/navigation_spec.dart';
import 'package:fl_clash/views/views.dart';

import 'dashboard/native_host.dart';
import 'proxies/native_host.dart';
import 'package:material_ui/material_ui.dart';

class Navigation implements NavigationPort {
  static Navigation? _instance;

  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool signedIn = false,
    bool hasSubscription = false,
  }) {
    final builders = <PageLabel, WidgetBuilder>{
      PageLabel.dashboard: (_) =>
          const NativeDashboardRoute(key: GlobalObjectKey(PageLabel.dashboard)),
      PageLabel.proxies: (_) =>
          const NativeProxiesRoute(key: GlobalObjectKey(PageLabel.proxies)),
      PageLabel.requests: (_) =>
          const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
      PageLabel.connections: (_) =>
          const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
      PageLabel.dns: (_) =>
          const DnsQueriesView(key: GlobalObjectKey(PageLabel.dns)),
      PageLabel.resources: (_) =>
          const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
      PageLabel.logs: (_) =>
          const LogsView(key: GlobalObjectKey(PageLabel.logs)),
      PageLabel.tools: (_) =>
          const NativeSettingsRoute(key: GlobalObjectKey(PageLabel.tools)),
      PageLabel.nativeIp: (_) =>
          const IpingNativeIpPage(key: GlobalObjectKey(PageLabel.nativeIp)),
      PageLabel.tunnels: (_) =>
          const IpingTunnelsPage(key: GlobalObjectKey(PageLabel.tunnels)),
      PageLabel.account: (_) =>
          const NativeAccountRoute(key: GlobalObjectKey(PageLabel.account)),
    };
    return [
      for (final label in appNavigationOrder)
        if (builders[label] case final builder?)
          for (final modes in [
            navigationModesFor(
              label,
              openLogs: openLogs,
              hasProxies: hasProxies,
              signedIn: signedIn,
              hasSubscription: hasSubscription,
            ),
          ])
            if (modes.isNotEmpty)
              NavigationItem(
                glyph: label.glyph,
                label: label,
                builder: builder,
                modes: modes,
              ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
