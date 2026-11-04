import 'package:material_ui/material_ui.dart';

import '../ui/ui.dart';
import 'user_info.dart';

class IpingAccountProfile {
  const IpingAccountProfile({
    required this.info,
    this.onTopUp,
    this.onHistory,
    this.showTopUp = true,
  });
  final IpingUserInfo info;
  final VoidCallback? onTopUp;
  final VoidCallback? onHistory;
  final bool showTopUp;
}

class IpingAccountSubscription {
  const IpingAccountSubscription({
    required this.nodes,
    required this.busy,
    required this.onSync,
    this.updatedText,
    this.failure,
    this.exportUrl,
    this.onImport,
    this.onSignIn,
    this.manualSubscription = false,
  });
  final int nodes;
  final bool busy;
  final VoidCallback onSync;
  final String? updatedText;
  final Widget? failure;
  final String? exportUrl;
  final VoidCallback? onImport;
  final VoidCallback? onSignIn;
  final bool manualSubscription;
}

abstract interface class IpingAccountHost {
  IpingAccountProfile? get profile;
  IpingAccountSubscription? get subscription;

  List<Widget> get sections;
  bool get loading;

  NullStatus? get empty;
  bool get busy;

  bool get hasAccountActions;
  VoidCallback? get onRefresh;
  VoidCallback? get onConsole;
  VoidCallback? get onSignOut;
}
