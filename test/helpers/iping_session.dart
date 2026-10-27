import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:fl_clash/iping/api.dart';

// Core lifecycle tests exercise an account with an available subscription.
final connectedAccountOverride = ipingSessionProvider.overrideWithBuild(
  (_, _) => const IpingSessionState(
    initialized: true,
    nodes: 1,
    account: IpingAccount(
      subscriptionToken: 'subscription',
      id: 1,
      email: 'test@example.com',
    ),
  ),
);
