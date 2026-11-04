import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../ui/icons/icons.dart';
import '../../ui/ui.dart';
import '../account_host.dart';
import '../profile_widgets.dart';
import '../subscription_page.dart';

class IpingAccountPage extends StatelessWidget {
  const IpingAccountPage({super.key, required this.host});

  final IpingAccountHost host;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = host.profile;
    final subscription = host.subscription;
    final empty = profile == null && subscription == null;
    final onRefresh = host.onRefresh;
    final onSync = subscription?.onSync;
    return CommonScaffold(
      title: l.ipingProfileCenter,
      primaryAction: onRefresh != null
          ? IconButtonData(
              glyph: AppGlyphs.refresh,
              tooltip: l.ipingRefreshAccount,
              isLoading: host.loading,
              onPressed: host.loading ? null : onRefresh,
            )
          : onSync == null
          ? null
          : IconButtonData(
              glyph: AppGlyphs.sync,
              tooltip: l.ipingSync,
              isLoading: subscription!.busy,
              onPressed: subscription.busy ? null : onSync,
            ),
      menuItems: [
        if (host.hasAccountActions) ...[
          CommonPopupMenuItem(
            glyph: AppGlyphs.openExternal,
            label: l.ipingConsole,
            onPressed: host.onConsole,
          ),
          CommonPopupMenuItem(
            glyph: AppGlyphs.arrowBack,
            label: l.ipingSignOut,
            danger: true,
            onPressed: host.busy ? null : host.onSignOut,
          ),
        ],
      ],
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: host.loading && empty,
          isEmpty: empty,
          nullStatus:
              host.empty ??
              NullStatus(
                label: l.noData,
                illustration: NullStatusIllustration.data,
              ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              context.appBarInset,
              16,
              24 + BottomInsetScope.of(context),
            ),
            children: [
              if (profile != null)
                IpingProfileHeader(
                  info: profile.info,
                  onTopUp: profile.onTopUp,
                  onHistory: profile.onHistory,
                  showTopUp: profile.showTopUp,
                )
              else
                ?host.empty,
              if (subscription != null) ...[
                if (profile != null || host.empty != null)
                  const SizedBox(height: 12),
                IpingSubscriptionSection(
                  nodes: subscription.nodes,
                  busy: subscription.busy,
                  updatedText: subscription.updatedText,
                  failure: subscription.failure,
                  exportUrl: subscription.exportUrl,
                  onImport: subscription.onImport,
                  onSignIn: subscription.onSignIn,
                  manualSubscription: subscription.manualSubscription,
                ),
              ],
              for (final section in host.sections) ...[
                const SizedBox(height: 12),
                section,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
