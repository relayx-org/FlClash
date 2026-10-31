import '../enum/page_label.dart';
import 'l10n.dart';

extension PageLabelPresentation on PageLabel {
  String labelOf(AppLocalizations appLocalizations) {
    return switch (this) {
      PageLabel.dashboard => appLocalizations.dashboard,
      PageLabel.proxies => appLocalizations.proxies,
      PageLabel.services => appLocalizations.services,
      PageLabel.profiles => appLocalizations.profiles,
      PageLabel.account => appLocalizations.ipingProfileCenter,
      PageLabel.nativeIp => appLocalizations.ipingNativeIp,
      PageLabel.tunnels => appLocalizations.ipingTunnels,
      PageLabel.tools => appLocalizations.settings,
      PageLabel.logs => appLocalizations.logs,
      PageLabel.requests => appLocalizations.recentRequests,
      PageLabel.resources => appLocalizations.resources,
      PageLabel.connections => appLocalizations.liveConnections,
      PageLabel.dns => appLocalizations.dnsQueries,
    };
  }
}
