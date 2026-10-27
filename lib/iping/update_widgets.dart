import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update.dart';
import 'update_provider.dart';

final ipingUpdateDialogsProvider = Provider((ref) => IpingUpdateDialogs());

class IpingUpdateDialogs {
  Future<void>? _pending;
  final _shown = <String>{};

  bool hasShown(IpingUpdate update) =>
      _shown.contains('${update.version}+${update.buildNumber}');

  Future<void> show(BuildContext context, IpingUpdater updater) {
    final update = updater.update;
    if (update != null) _shown.add('${update.version}+${update.buildNumber}');
    return _pending ??= dialogs
        .showCommonDialog<void>(
          context: context,
          child: IpingUpdateDialog(updater: updater),
        )
        .whenComplete(() => _pending = null);
  }
}

class IpingCheckUpdateItem extends ConsumerWidget {
  const IpingCheckUpdateItem({super.key});

  Future<void> _check(
    BuildContext context,
    WidgetRef ref,
    IpingUpdater updater,
  ) async {
    if (!updater.busy) await updater.check();
    if (!context.mounted) return;
    if (updater.update != null && !updater.checkFailed) {
      await ref.read(ipingUpdateDialogsProvider).show(context, updater);
    } else {
      final l = context.appLocalizations;
      await dialogs.showMessage(
        context: context,
        title: l.checkUpdate,
        message: TextSpan(
          text: updater.checkFailed
              ? l.ipingUpdateCheckFailed
              : l.checkUpdateError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updater = ref.watch(ipingUpdaterProvider);
    final l = context.appLocalizations;
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) => ListItem(
        leading: const GlyphIcon(AppGlyphs.refresh),
        title: Text(l.checkUpdate),
        trailing: updater.checking || updater.busy
            ? const CommonCircleLoading(size: 20)
            : null,
        onTap: !updater.enabled || updater.checking
            ? null
            : () => _check(context, ref, updater),
      ),
    );
  }
}

class IpingUpdateDialog extends StatelessWidget {
  const IpingUpdateDialog({super.key, required this.updater});
  final IpingUpdater updater;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final l = context.appLocalizations;
      final update = updater.update;
      if (update == null) {
        return CommonDialog(
          title: l.checkUpdate,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.close),
            ),
          ],
          child: Text(l.checkUpdateError),
        );
      }
      return CommonDialog(
        title: l.discoverNewVersion,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(updater.busy ? l.close : l.ipingUpdateLater),
          ),
          FilledButton(
            onPressed: updater.busy || updater.checking
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
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.ipingUpdateAvailableDesc(update.version)),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(update.notes, style: AppTextStyle.subheadline.of(context)),
            ],
            if (updater.busy && !update.isAppStore) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: updater.progress),
              const SizedBox(height: 12),
              Text(
                '${((updater.progress ?? 0) * 100).round()}%',
                textAlign: TextAlign.center,
              ),
            ],
            if (updater.failed) ...[
              const SizedBox(height: 16),
              Text(
                update.isAppStore
                    ? l.ipingUpdateAppStoreFailed
                    : l.ipingUpdateFailed,
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
              if (!update.isAppStore)
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
      );
    },
  );
}
