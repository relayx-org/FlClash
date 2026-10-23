import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_layout.dart';
import 'api.dart';
import 'providers.dart';
import 'subscription.dart';

class IpingGate extends ConsumerWidget {
  const IpingGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(ipingSessionProvider);
    if (!ref.watch(initProvider) || !session.initialized) {
      return const Scaffold(body: Center(child: CommonCircleLoading.page()));
    }
    return session.account == null ? const IpingLoginView() : child;
  }
}

class IpingLoginView extends ConsumerWidget {
  const IpingLoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final session = ref.watch(ipingSessionProvider);
    final site = ref.watch(ipingSiteConfigProvider);
    final controller = ref.read(ipingSessionProvider.notifier).controller;
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
              if (session.failure case final failure?) ...[
                IpingFailureText(failure: failure),
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
                onPressed: session.busy ? null : controller.signIn,
                child: session.busy
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
                  onPressed: session.busy
                      ? null
                      : () => controller.signIn(register: true),
                  child: Text(l.ipingRegister),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: session.busy
                      ? null
                      : () => launchUrl(
                          Uri.parse('$ipingSite/handler/forgot-password'),
                          mode: LaunchMode.externalApplication,
                        ),
                  child: Text(l.ipingForgotPassword),
                ),
              ),
              if (session.busy) ...[
                const SizedBox(height: 16),
                Text(
                  l.ipingBrowserWaiting,
                  style: AppTextStyle.subheadline.of(context),
                ),
                TextButton(
                  onPressed: controller.cancelSignIn,
                  child: Text(l.cancel),
                ),
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
                    onPressed: () =>
                        dialogs.openUrl('$ipingSite/terms-of-service.html'),
                    child: Text(l.ipingTerms),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        dialogs.openUrl('$ipingSite/privacy-policy.html'),
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
