import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'brand.dart';
import 'site_config.dart';

class IpingAccountMenu extends StatelessWidget {
  const IpingAccountMenu({
    super.key,
    required this.email,
    required this.site,
    required this.busy,
    required this.onConsole,
    required this.onSignOut,
    this.menuBuilder,
  });
  final String? email;
  final IpingSiteConfig site;
  final bool busy;
  final VoidCallback onConsole;
  final VoidCallback onSignOut;
  final WidgetBuilder? menuBuilder;
  @override
  Widget build(BuildContext context) {
    final email = this.email;
    if (email == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: IpingLogo(src: site.logoUrl, size: 28)),
      );
    }
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: CommonPopupBox(
        placement: PopupPlacement.overAnchorStart,
        targetBuilder: (open) => Tooltip(
          message: '${l.ipingAccount}\n$email',
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
                              email,
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
        popupBuilder:
            menuBuilder ??
            (_) => IpingAccountActions(
              busy: busy,
              onConsole: onConsole,
              onSignOut: onSignOut,
            ),
      ),
    );
  }
}

class IpingAccountActions extends StatelessWidget {
  const IpingAccountActions({
    super.key,
    required this.busy,
    required this.onConsole,
    required this.onSignOut,
  });
  final bool busy;
  final VoidCallback onConsole;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonPopupMenu(
      items: [
        CommonPopupMenuItem(
          label: l.ipingConsole,
          glyph: AppGlyphs.openExternal,
          onPressed: onConsole,
        ),
        CommonPopupMenuItem(
          label: l.ipingSignOut,
          glyph: AppGlyphs.arrowBack,
          danger: true,
          onPressed: busy ? null : onSignOut,
        ),
      ],
    );
  }
}

class IpingAccountSummary extends StatelessWidget {
  const IpingAccountSummary({
    super.key,
    required this.email,
    required this.site,
    required this.busy,
    required this.onConsole,
    required this.onSignOut,
  });
  final String email;
  final IpingSiteConfig site;
  final bool busy;
  final VoidCallback onConsole;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signOutColor = busy
        ? context.colorScheme.onSurface.withValues(alpha: 0.38)
        : context.colorScheme.error;
    return generateSection(
      title: l.ipingAccount,
      items: [
        ListItem(
          leading: IpingLogo(src: site.logoUrl, size: 28),
          title: Text(site.name),
          subtitle: Text(email),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.openExternal),
          title: Text(l.ipingConsole),
          onTap: onConsole,
        ),
        ListItem(
          leading: GlyphIcon(AppGlyphs.arrowBack, color: signOutColor),
          title: Text(l.ipingSignOut, style: TextStyle(color: signOutColor)),
          onTap: busy ? null : onSignOut,
        ),
      ],
    );
  }
}
