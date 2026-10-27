import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update.dart';
import 'update_provider.dart';

class IpingUpdateGate extends ConsumerStatefulWidget {
  const IpingUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<IpingUpdateGate> createState() => _IpingUpdateGateState();
}

class _IpingUpdateGateState extends ConsumerState<IpingUpdateGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastResumeCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final updater = ref.read(ipingUpdaterProvider);
    if (!updater.enabled) return;
    scheduleMicrotask(() {
      if (mounted) unawaited(updater.initialize());
    });
    _timer = Timer.periodic(const Duration(hours: 1), (_) => updater.check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_lastResumeCheck != null &&
        now.difference(_lastResumeCheck!) < const Duration(minutes: 5)) {
      return;
    }
    _lastResumeCheck = now;
    unawaited(ref.read(ipingUpdaterProvider).check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updater = ref.watch(ipingUpdaterProvider);
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: updater.required,
            child: ExcludeFocus(
              excluding: updater.required,
              child: widget.child,
            ),
          ),
          if (updater.required)
            HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => ListenableBuilder(
                    listenable: updater,
                    builder: (_, _) => IpingRequiredUpdate(updater: updater),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class IpingRequiredUpdate extends StatelessWidget {
  const IpingRequiredUpdate({super.key, required this.updater});
  final IpingUpdater updater;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final update = updater.update!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.ipingUpdateRequired,
                    style: AppTextStyle.title1.of(context, emphasized: true),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.ipingUpdateRequiredDesc(update.version),
                    style: AppTextStyle.body.of(context),
                  ),
                  if (update.notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      update.notes,
                      style: AppTextStyle.subheadline.of(context),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (updater.busy && !update.isAppStore) ...[
                    LinearProgressIndicator(value: updater.progress),
                    const SizedBox(height: 12),
                    Text(
                      '${((updater.progress ?? 0) * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (updater.failed) ...[
                    Text(
                      update.isAppStore
                          ? l.ipingUpdateAppStoreFailed
                          : l.ipingUpdateFailed,
                      style: AppTextStyle.body
                          .of(context)
                          .copyWith(color: context.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton(
                    onPressed: updater.busy
                        ? null
                        : () => updater.install(
                            askPassword: () => dialogs.showCommonDialog<String>(
                              context: context,
                              child: InputDialog(
                                title: l.sudoPasswordTitle,
                                value: '',
                                labelText: l.password,
                                obscureText: true,
                              ),
                            ),
                          ),
                    child: updater.busy && update.isAppStore
                        ? const CommonCircleLoading(size: 20)
                        : Text(
                            updater.failed
                                ? l.retry
                                : update.isAppStore
                                ? l.ipingUpdateOpenAppStore
                                : l.update,
                          ),
                  ),
                  if (updater.failed && !update.isAppStore) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => launchUrl(
                        update.url,
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(l.ipingUpdateManualDownload),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    update.isAppStore
                        ? l.ipingUpdateAppStoreHint
                        : l.ipingUpdateInstallHint,
                    style: AppTextStyle.footnote.of(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
