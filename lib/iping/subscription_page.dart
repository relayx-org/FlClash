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
    required this.onConsole,
  });
  final int nodes;
  final bool busy;
  final String? updatedText;
  final Widget? failure;
  final VoidCallback onSync;
  final VoidCallback onConsole;
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
              nodes > 0 ? l.ipingNodeCount(nodes) : l.ipingNoNodes,
              style: AppTextStyle.headline.of(context),
            ),
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
            const SizedBox(height: 12),
            TextButton(onPressed: onConsole, child: Text(l.ipingConsole)),
          ],
        ),
      ),
    );
  }
}
