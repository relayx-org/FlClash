import '../enum/navigation_item_mode.dart';
import '../enum/page_label.dart';

const appNavigationOrder = [
  PageLabel.dashboard,
  PageLabel.proxies,
  PageLabel.requests,
  PageLabel.connections,
  PageLabel.dns,
  PageLabel.resources,
  PageLabel.logs,
  PageLabel.tools,
  PageLabel.nativeIp,
  PageLabel.tunnels,
  PageLabel.account,
];

List<NavigationItemMode> navigationModesFor(
  PageLabel label, {
  required bool openLogs,
  required bool hasProxies,
  required bool signedIn,
  required bool hasSubscription,
}) {
  return switch (label) {
    PageLabel.dashboard => const [
      NavigationItemMode.mobile,
      NavigationItemMode.desktop,
    ],
    PageLabel.proxies =>
      hasProxies
          ? const [NavigationItemMode.mobile, NavigationItemMode.desktop]
          : const [],
    PageLabel.requests => const [NavigationItemMode.moreFull],
    PageLabel.connections => const [
      NavigationItemMode.desktop,
      NavigationItemMode.moreFull,
    ],
    PageLabel.dns => const [NavigationItemMode.moreFull],
    PageLabel.resources => const [NavigationItemMode.more],
    PageLabel.logs =>
      openLogs
          ? const [NavigationItemMode.desktop, NavigationItemMode.more]
          : const [],
    PageLabel.tools => const [
      NavigationItemMode.desktop,
      NavigationItemMode.mobile,
    ],
    PageLabel.nativeIp =>
      signedIn ? const [NavigationItemMode.desktop] : const [],
    PageLabel.tunnels =>
      signedIn ? const [NavigationItemMode.desktop] : const [],
    PageLabel.profiles => const [],
    PageLabel.account => [
      if (hasSubscription) NavigationItemMode.mobile,
      if (signedIn) NavigationItemMode.desktop,
    ],
  };
}
