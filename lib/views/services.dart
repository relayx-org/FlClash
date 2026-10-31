import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../iping/account.dart';
import '../iping/native_ip_page.dart';
import '../iping/profile.dart';
import '../iping/providers.dart';
import '../iping/tunnel_page.dart';
import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

/// The account and its store, which the mobile tab bar keeps out of settings:
/// the pages there would otherwise sit in the more tools drawer.
class ServicesView extends ConsumerWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(
      ipingSessionProvider.select((state) => state.account != null),
    );
    return CommonScaffold(
      title: l.services,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: context.appBarInset,
            bottom: 20 + BottomInsetScope.of(context),
          ),
          children: [
            const IpingAccountSection(accountCenter: IpingProfile()),
            if (signedIn)
              generateSection(
                title: l.services,
                items: [
                  ListItem.open(
                    leading: const GlyphIcon(AppGlyphs.locate),
                    title: Text(l.ipingNativeIp),
                    widget: const IpingNativeIpPage(),
                  ),
                  ListItem.open(
                    leading: const GlyphIcon(AppGlyphs.swap),
                    title: Text(l.ipingTunnels),
                    widget: const IpingTunnelsPage(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
