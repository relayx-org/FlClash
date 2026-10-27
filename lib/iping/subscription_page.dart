import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/ui.dart';

class IpingSubscriptionPage extends StatelessWidget {
  const IpingSubscriptionPage({
    super.key,
    required this.nodes,
    required this.busy,
    this.updatedText,
    this.failure,
    required this.onSync,
    this.onConsole,
    this.onImport,
    this.onSignIn,
    this.manualSubscription = false,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final VoidCallback onSync;
  final VoidCallback? onConsole;
  final VoidCallback? onImport;
  final VoidCallback? onSignIn;
  final bool manualSubscription;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.subscriptionInfo,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            context.appBarInset + 24,
            24,
            32 + BottomInsetScope.of(context),
          ),
          children: [
            Text(
              nodes > 0
                  ? l.ipingNodeCount(nodes)
                  : manualSubscription
                  ? l.ipingManualNoNodes
                  : l.ipingNoNodes,
              style: AppTextStyle.headline.of(context),
            ),
            if (manualSubscription) ...[
              const SizedBox(height: 12),
              Text(
                l.ipingManualSubscription,
                style: AppTextStyle.footnote.of(context),
              ),
            ],
            if (updatedText != null) ...[
              const SizedBox(height: 12),
              Text(updatedText!, style: AppTextStyle.footnote.of(context)),
            ],
            if (failure case final message?) ...[
              const SizedBox(height: 16),
              message,
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : onSync,
              child: Text(busy ? l.ipingSyncing : l.ipingSync),
            ),
            if (onImport != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : onImport,
                child: Text(l.ipingImportSubscription),
              ),
            ],
            if (onSignIn != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : onSignIn,
                child: Text(l.ipingBrowserLogin),
              ),
            ],
            if (onConsole != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onConsole, child: Text(l.ipingConsole)),
            ],
          ],
        ),
      ),
    );
  }
}
