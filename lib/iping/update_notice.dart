import 'dart:async';

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'update.dart';
import 'update_provider.dart';
import 'update_widgets.dart';

class IpingUpdateNotice extends ConsumerStatefulWidget {
  const IpingUpdateNotice({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<IpingUpdateNotice> createState() => _IpingUpdateNoticeState();
}

class _IpingUpdateNoticeState extends ConsumerState<IpingUpdateNotice>
    with WidgetsBindingObserver {
  late final IpingUpdater _updater;
  Timer? _timer;
  DateTime? _lastResumeCheck;

  @override
  void initState() {
    super.initState();
    _updater = ref.read(ipingUpdaterProvider);
    if (!_updater.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_check());
    });
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _check());
  }

  Future<void> _check() async {
    await _updater.check();
    if (!mounted || _updater.checkFailed) return;
    final update = _updater.update;
    final navigatorContext = rootNavigatorKey.currentContext;
    if (update == null ||
        navigatorContext == null ||
        !navigatorContext.mounted) {
      return;
    }
    final prompts = ref.read(ipingUpdateDialogsProvider);
    if (prompts.hasShown(update)) return;
    await prompts.show(navigatorContext, _updater);
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
    unawaited(_check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
