import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic_frame.dart';
import 'package:fl_clash/views/dashboard/widgets/speed_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'desktop and mobile traffic cards follow the same event snapshot',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 1024, down: 2048));
      container.read(totalTrafficProvider.notifier).value = const Traffic(
        up: 100000,
        down: 200000,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: SpeedCard(direction: TrafficDirection.upload),
                  ),
                  NetworkSpeedCard(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final desktop = tester.widget<DashboardTrafficSpeedCard>(
        find.byType(DashboardTrafficSpeedCard),
      );
      final mobile = tester.widget<DashboardNetworkSpeedCard>(
        find.byType(DashboardNetworkSpeedCard),
      );
      expect(identical(desktop.traffic, mobile.traffic), isTrue);
      expect(desktop.traffic.latest, const Traffic(up: 1024, down: 2048));
      expect(desktop.traffic.total.up, 100000);
      container
          .read(trafficsProvider.notifier)
          .addTraffic(const Traffic(up: 4096));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DashboardTrafficSpeedCard>(
              find.byType(DashboardTrafficSpeedCard),
            )
            .traffic
            .latest
            .up,
        4096,
      );
      expect(desktop.traffic.latest.up, 1024);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a disconnected traffic card displays the shared empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        child: Scaffold(
          body: SizedBox(
            height: 260,
            child: DashboardTrafficSpeedCard(
              direction: TrafficDirection.upload,
              traffic: IpingTrafficSnapshot.empty(),
              connected: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final figure = tester.widget<DashboardTrafficFigure>(
      find.byType(DashboardTrafficFigure),
    );
    expect(figure.value, '—');
    expect(figure.unit, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
