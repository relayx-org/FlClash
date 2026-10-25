import 'package:fl_clash/iping/backend_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'traffic_frame.dart';
export 'traffic_frame.dart' show TrafficDirection;

class SpeedCard extends ConsumerWidget {
  const SpeedCard({super.key, required this.direction});

  final TrafficDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      DashboardTrafficSpeedCard(
        direction: direction,
        traffic: ref.watch(ipingTrafficProvider),
      );
}

class NetworkSpeedCard extends ConsumerWidget {
  const NetworkSpeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      DashboardNetworkSpeedCard(traffic: ref.watch(ipingTrafficProvider));
}
