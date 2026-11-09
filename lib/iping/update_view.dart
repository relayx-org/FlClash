import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

enum IpingUpdateKind { package, appStore, router }

abstract interface class IpingUpdateOffer {
  String get version;
  int get buildNumber;
  String get notes;
  IpingUpdateKind get kind;

  /// Where the package can be downloaded by hand after a failed update.
  Uri? get url;
}

/// The update flow the check item and dialog drive, whichever mechanism
/// installs the update underneath.
abstract interface class IpingUpdateController implements Listenable {
  bool get enabled;
  IpingUpdateOffer? get update;
  bool get checking;
  bool get checkFailed;
  bool get busy;
  bool get failed;

  /// The install's progress from 0 to 1, or null when it cannot be measured.
  double? get progress;
  Future<void> check();
  Future<void> install({Future<String?> Function()? askPassword});
}

class IpingUpdateDialogs {
  Future<void>? _pending;
  final _shown = <String>{};

  bool hasShown(IpingUpdateOffer update) =>
      _shown.contains('${update.version}+${update.buildNumber}');

  Future<void> show(BuildContext context, IpingUpdateController updater) {
    final update = updater.update;
    if (update != null) _shown.add('${update.version}+${update.buildNumber}');
    return _pending ??= showFloatingDialog<void>(
      context: context,
      child: IpingUpdateDialog(updater: updater),
    ).whenComplete(() => _pending = null);
  }
}

class IpingUpdateCheckItem extends StatelessWidget {
  const IpingUpdateCheckItem({
    super.key,
    required this.updater,
    required this.dialogs,
    this.showResult = _showResult,
  });
  final IpingUpdateController updater;
  final IpingUpdateDialogs dialogs;
  final Future<void> Function(BuildContext context, String message) showResult;

  static Future<void> _showResult(BuildContext context, String message) =>
      showFloatingDialog<void>(
        context: context,
        child: Builder(
          builder: (context) {
            final l = AppLocalizations.of(context);
            return CommonDialog(
              title: l.checkUpdate,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.confirm),
                ),
              ],
              child: Text(message),
            );
          },
        ),
      );

  Future<void> _check(BuildContext context) async {
    if (!updater.busy) await updater.check();
    if (!context.mounted) return;
    if (updater.update != null && !updater.checkFailed) {
      await dialogs.show(context, updater);
      return;
    }
    final l = AppLocalizations.of(context);
    await showResult(
      context,
      updater.checkFailed ? l.ipingUpdateCheckFailed : l.checkUpdateError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            : () => _check(context),
      ),
    );
  }
}

class IpingUpdateDialog extends StatelessWidget {
  const IpingUpdateDialog({super.key, required this.updater});
  final IpingUpdateController updater;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
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
      final appStore = update.kind == IpingUpdateKind.appStore;
      final download = update.url;
      final progress = updater.progress;
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
                    askPassword: () => showFloatingDialog<String>(
                      context: context,
                      child: InputDialog(
                        title: l.sudoPasswordTitle,
                        value: '',
                        labelText: l.password,
                        obscureText: true,
                      ),
                    ),
                  ),
            child: updater.busy && appStore
                ? const CommonCircleLoading(size: 20)
                : Text(
                    updater.failed
                        ? l.retry
                        : appStore
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
            if (updater.busy && !appStore) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress),
              if (progress != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${(progress * 100).round()}%',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            if (updater.failed) ...[
              const SizedBox(height: 16),
              Text(
                switch (update.kind) {
                  IpingUpdateKind.appStore => l.ipingUpdateAppStoreFailed,
                  IpingUpdateKind.router => l.routerUpdateFailed,
                  IpingUpdateKind.package => l.ipingUpdateFailed,
                },
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
              if (!appStore && download != null)
                TextButton(
                  onPressed: () =>
                      launchUrl(download, mode: LaunchMode.externalApplication),
                  child: Text(l.ipingUpdateManualDownload),
                ),
            ],
            const SizedBox(height: 12),
            Text(switch (update.kind) {
              IpingUpdateKind.appStore => l.ipingUpdateAppStoreHint,
              IpingUpdateKind.router => l.routerUpdateHint,
              IpingUpdateKind.package => l.ipingUpdateInstallHint,
            }, style: AppTextStyle.footnote.of(context)),
          ],
        ),
      );
    },
  );
}
