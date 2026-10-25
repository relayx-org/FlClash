import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import 'login_layout.dart';
import 'site_config.dart';

class IpingLoginPage extends StatelessWidget {
  const IpingLoginPage({
    super.key,
    required this.site,
    required this.busy,
    this.failure,
    required this.onSignIn,
    required this.onRegister,
    required this.onCancel,
    required this.onForgotPassword,
    required this.onTerms,
    required this.onPrivacy,
  });

  final IpingSiteConfig site;
  final bool busy;
  final Widget? failure;
  final VoidCallback onSignIn;
  final VoidCallback onRegister;
  final VoidCallback onCancel;
  final VoidCallback onForgotPassword;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: IpingLoginLayout(
          site: site,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GlyphIcon(
                    AppGlyphs.account,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.ipingAccount,
                    style: AppTextStyle.caption1.of(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l.ipingWelcome(site.name),
                style: AppTextStyle.largeTitle.of(context, emphasized: true),
              ),
              const SizedBox(height: 12),
              Text(
                l.ipingBrowserHint(site.name),
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              if (failure case final message?) ...[
                message,
                const SizedBox(height: 16),
              ],
              if (!site.allowRegister) ...[
                Text(
                  l.ipingRegistrationClosed,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: busy ? null : onSignIn,
                child: busy
                    ? const CommonCircleLoading(size: 20)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GlyphIcon(
                            AppGlyphs.openExternal,
                            fill: 1,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(l.ipingBrowserLogin)),
                        ],
                      ),
              ),
              if (site.allowRegister) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: context.colorScheme.onSurface,
                  ),
                  onPressed: busy ? null : () => onRegister(),
                  child: Text(l.ipingRegister),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: busy ? null : onForgotPassword,
                  child: Text(l.ipingForgotPassword),
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                Text(
                  l.ipingBrowserWaiting,
                  style: AppTextStyle.subheadline.of(context),
                ),
                TextButton(onPressed: onCancel, child: Text(l.cancel)),
              ],
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlyphIcon(
                    AppGlyphs.lock,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.ipingLoginSecurityNote,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onTerms,
                    child: Text(l.ipingTerms),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onPrivacy,
                    child: Text(l.ipingPrivacy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
