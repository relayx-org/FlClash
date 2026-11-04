import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'subscription_export.dart';

class IpingSubscriptionPage extends StatelessWidget {
  const IpingSubscriptionPage({
    super.key,
    required this.nodes,
    required this.busy,
    this.updatedText,
    this.failure,
    this.exportUrl,
    required this.onSync,
    this.onImport,
    this.onSignIn,
    this.manualSubscription = false,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final String? exportUrl;
  final VoidCallback onSync;
  final VoidCallback? onImport;
  final VoidCallback? onSignIn;
  final bool manualSubscription;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.subscriptionInfo,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.sync,
        tooltip: l.ipingSync,
        isLoading: busy,
        onPressed: busy ? null : onSync,
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            IpingSubscriptionSection(
              nodes: nodes,
              busy: busy,
              updatedText: updatedText,
              failure: failure,
              exportUrl: exportUrl,
              onImport: onImport,
              onSignIn: onSignIn,
              manualSubscription: manualSubscription,
            ),
          ],
        ),
      ),
    );
  }
}

class IpingSubscriptionSection extends StatelessWidget {
  const IpingSubscriptionSection({
    super.key,
    required this.nodes,
    required this.busy,
    this.updatedText,
    this.failure,
    this.exportUrl,
    this.onImport,
    this.onSignIn,
    this.manualSubscription = false,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final String? exportUrl;
  final VoidCallback? onImport;
  final VoidCallback? onSignIn;
  final bool manualSubscription;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colorScheme;
    final actions = <Widget>[
      if (onImport != null)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(l.ipingImportSubscription),
          onTap: busy ? null : onImport,
        ),
      if (exportUrl case final url?)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.qrCode),
          title: Text(l.ipingExportSubscription),
          onTap: () => showIpingSubscriptionExport(
            context,
            hint: l.ipingAccountSubscriptionHint,
            warning: l.ipingSubscriptionSecretHint,
            loadUrl: () async => url,
          ),
        ),
      if (onSignIn != null)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.account),
          title: Text(l.ipingBrowserLogin),
          onTap: busy ? null : onSignIn,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nodes == 0 || manualSubscription)
          CommonCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: nodes == 0
                      ? Text(
                          manualSubscription
                              ? l.ipingManualNoNodes
                              : l.ipingNoNodes,
                          style: AppTextStyle.body
                              .of(context)
                              .copyWith(color: scheme.onSurfaceVariant),
                        )
                      : const SizedBox.shrink(),
                ),
                if (manualSubscription)
                  MetaChip(label: l.ipingManualSubscriptionShort),
              ],
            ),
          ),
        if (manualSubscription) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.ipingManualSubscription,
              style: context.listCaptionStyle,
            ),
          ),
        ],
        if (failure case final message?) ...[
          const SizedBox(height: 16),
          message,
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          generateSection(title: l.action, items: actions),
        ],
      ],
    );
  }
}
