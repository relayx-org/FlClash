import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_page.dart';
import 'backend_native.dart';
import 'api.dart';
import 'providers.dart';
import 'subscription.dart';

class IpingGate extends ConsumerWidget {
  const IpingGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ipingClientControllerProvider);
    final session = ref.watch(ipingBackendStateProvider);
    if (!ref.watch(initProvider) || !session.initialized) {
      return const Scaffold(body: Center(child: CommonCircleLoading.page()));
    }
    return !session.hasSubscription ? const IpingLoginView() : child;
  }
}

class IpingLoginView extends ConsumerWidget {
  const IpingLoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(ipingSessionProvider);
    final backend = ref.read(ipingClientControllerProvider);
    return IpingLoginPage(
      site: ref.watch(ipingSiteConfigProvider),
      busy: session.busy,
      showBrowserWaiting: backend.authorizing,
      failure: session.failure == null
          ? null
          : IpingFailureText(failure: session.failure!),
      onSignIn: backend.signIn,
      onRegister: () => backend.signIn(register: true),
      onCancel: backend.cancelSignIn,
      onImport: () => importIpingSubscription(context, ref),
      onForgotPassword: () => launchUrl(
        Uri.parse('$ipingSite/handler/forgot-password'),
        mode: LaunchMode.externalApplication,
      ),
      onTerms: () => dialogs.openUrl('$ipingSite/terms-of-service.html'),
      onPrivacy: () => dialogs.openUrl('$ipingSite/privacy-policy.html'),
    );
  }
}
