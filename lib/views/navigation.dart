import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/iping/profile.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/page_destination.dart';
import 'package:fl_clash/views/views.dart';
import 'package:material_ui/material_ui.dart';

class Navigation implements NavigationPort {
  static Navigation? _instance;

  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool signedIn = false,
  }) {
    return [
      NavigationItem(
        glyph: PageLabel.dashboard.glyph,
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
      ),
      NavigationItem(
        glyph: PageLabel.proxies.glyph,
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        glyph: PageLabel.requests.glyph,
        label: PageLabel.requests,
        builder: (_) =>
            const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
        modes: [NavigationItemMode.moreFull],
      ),
      NavigationItem(
        glyph: PageLabel.connections.glyph,
        label: PageLabel.connections,
        builder: (_) =>
            const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.moreFull],
      ),
      NavigationItem(
        glyph: PageLabel.dns.glyph,
        label: PageLabel.dns,
        builder: (_) =>
            const DnsQueriesView(key: GlobalObjectKey(PageLabel.dns)),
        modes: [NavigationItemMode.moreFull],
      ),
      NavigationItem(
        glyph: PageLabel.resources.glyph,
        label: PageLabel.resources,
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        glyph: PageLabel.logs.glyph,
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        modes: openLogs
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        glyph: PageLabel.tools.glyph,
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        glyph: PageLabel.nativeIp.glyph,
        label: PageLabel.nativeIp,
        builder: (_) =>
            const IpingNativeIpPage(key: GlobalObjectKey(PageLabel.nativeIp)),
        modes: signedIn
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        glyph: PageLabel.tunnels.glyph,
        label: PageLabel.tunnels,
        builder: (_) =>
            const IpingTunnelsPage(key: GlobalObjectKey(PageLabel.tunnels)),
        modes: signedIn
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        glyph: PageLabel.account.glyph,
        label: PageLabel.account,
        builder: (_) =>
            const IpingProfile(key: GlobalObjectKey(PageLabel.account)),
        modes: signedIn
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
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
