import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'update.dart';
import 'update_installer.dart';

final ipingUpdaterProvider = Provider<IpingUpdater>((ref) {
  final updater = IpingUpdater(
    current: () => globalState.packageInfo,
    target: Platform.isIOS ? Future.value('ios') : ipingUpdateTarget(),
    client: IpingUpdateClient(),
    enabled: !Platform.isIOS && kReleaseMode && !safeModeBuild,
    onRequired: () async {
      await app?.setConnectionAllowed(false);
      await ref.read(setupActionProvider.notifier).setRunning(false);
    },
    beforeInstall: () =>
        ref.read(systemActionProvider.notifier).prepareForUpdate(),
    exitApplication: () => ref.read(systemActionProvider.notifier).handleExit(),
  );
  ref.onDispose(updater.dispose);
  return updater;
});
