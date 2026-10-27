import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'update.dart';
import 'update_installer.dart';
import 'update_app_store.dart';

final ipingUpdaterProvider = Provider<IpingUpdater>((ref) {
  final updater = IpingUpdater(
    current: () => globalState.packageInfo,
    target: ipingUpdateTarget(),
    client: Platform.isIOS ? IpingAppStoreUpdateClient() : IpingUpdateClient(),
    enabled: kReleaseMode && !safeModeBuild,
    beforeInstall: () =>
        ref.read(systemActionProvider.notifier).prepareForUpdate(),
    exitApplication: () => ref.read(systemActionProvider.notifier).handleExit(),
  );
  ref.onDispose(updater.dispose);
  return updater;
});
