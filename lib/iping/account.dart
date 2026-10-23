import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'brand.dart';
import 'api.dart';
import 'providers.dart';

class IpingAccountButton extends ConsumerWidget {
  const IpingAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(ipingSessionProvider.select((s) => s.account));
    final site = ref.watch(ipingSiteConfigProvider);
    if (account == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: IpingLogo(src: site.logoUrl, size: 28)),
      );
    }
    final l = context.appLocalizations;
    final notifier = ref.read(ipingSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: CommonPopupBox(
        placement: PopupPlacement.overAnchorStart,
        targetBuilder: (open) => Tooltip(
          message: '${l.ipingAccount}\n${account.email}',
          child: TextButton(
            onPressed: open,
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final expanded = constraints.maxWidth >= 140;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IpingLogo(src: site.logoUrl, size: 28),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              site.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.subheadline.of(context),
                            ),
                            Text(
                              account.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.caption2
                                  .of(context)
                                  .copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const GlyphIcon(AppGlyphs.chevronDown, size: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        popupBuilder: (_) => Consumer(
          builder: (_, ref, _) => CommonPopupMenu(
            items: [
              CommonPopupMenuItem(
                label: l.ipingConsole,
                glyph: AppGlyphs.openExternal,
                onPressed: () => dialogs.openUrl('$ipingSite/home'),
              ),
              CommonPopupMenuItem(
                label: l.ipingSignOut,
                glyph: AppGlyphs.arrowBack,
                danger: true,
                onPressed: ref.watch(ipingSessionProvider.select((s) => s.busy))
                    ? null
                    : () => notifier.controller.signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IpingAccountSection extends ConsumerWidget {
  const IpingAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(ipingSessionProvider);
    final account = session.account;
    if (account == null) return const SizedBox.shrink();
    final l = context.appLocalizations;
    return generateSection(
      title: l.ipingAccount,
      items: const [IpingAccountButton()],
    );
  }
}
