import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'subscription_export.dart';
import 'subscription_url.dart';

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
    this.onRemove,
    this.onSignIn,
    this.manualUrl,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final String? exportUrl;
  final VoidCallback onSync;
  final VoidCallback? onImport;
  final VoidCallback? onRemove;
  final VoidCallback? onSignIn;
  final String? manualUrl;

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
              onRemove: onRemove,
              onSignIn: onSignIn,
              manualUrl: manualUrl,
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
    this.onRemove,
    this.onSignIn,
    this.manualUrl,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final String? exportUrl;
  final VoidCallback? onImport;
  final VoidCallback? onRemove;
  final VoidCallback? onSignIn;
  final String? manualUrl;

  Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).ipingSubscriptionLinkCopied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colorScheme;
    final manualUrl = this.manualUrl;
    final emptyText = Text(
      manualUrl != null ? l.ipingManualNoNodes : l.ipingNoNodes,
      style: AppTextStyle.body
          .of(context)
          .copyWith(color: scheme.onSurfaceVariant),
    );
    final actions = <Widget>[
      if (onImport != null)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.link),
          title: Text(
            manualUrl != null
                ? l.ipingReplaceSubscription
                : l.ipingImportSubscription,
          ),
          onTap: busy ? null : onImport,
        ),
      if (manualUrl != null)
        ListItem(
          leading: const GlyphIcon(AppGlyphs.copy),
          title: Text(l.ipingCopySubscription),
          onTap: () => _copy(context, manualUrl),
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
      if (manualUrl != null && onRemove != null)
        ListItem(
          leading: GlyphIcon(AppGlyphs.delete, color: scheme.error),
          title: Text(
            l.ipingRemoveManualSubscription,
            style: TextStyle(color: scheme.error),
          ),
          onTap: busy ? null : onRemove,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (manualUrl != null)
          CommonCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ipingManualSubscriptionShort,
                  style: AppTextStyle.body.of(context, emphasized: true),
                ),
                const SizedBox(height: 2),
                Text(
                  maskIpingSubscriptionUrl(manualUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listCaptionStyle,
                ),
                if (nodes == 0) ...[const SizedBox(height: 8), emptyText],
              ],
            ),
          )
        else if (nodes == 0)
          CommonCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: emptyText,
          ),
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
