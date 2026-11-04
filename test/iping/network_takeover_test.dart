import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/iping/widgets/network_takeover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _Takeover implements IpingNetworkTakeover {
  _Takeover({this.supportsSystemProxy = true});

  @override
  final bool supportsSystemProxy;

  @override
  bool get supportsTun => true;

  @override
  bool systemProxy = false;

  @override
  bool tun = false;

  Exception? failure;
  final calls = <String>[];
  _Host? host;

  @override
  Future<void> setSystemProxy(bool value) async {
    calls.add('systemProxy:$value');
    if (failure case final failure?) throw failure;
    systemProxy = value;
    host?.notifyListeners();
  }

  @override
  Future<void> setTun(bool value) async {
    calls.add('tun:$value');
    if (failure case final failure?) throw failure;
    tun = value;
    host?.notifyListeners();
  }
}

class _Host extends ChangeNotifier implements IpingDashboardHost {
  _Host(this.takeover) {
    takeover.host = this;
  }

  final _Takeover takeover;

  @override
  IpingNetworkTakeover get networkTakeover => takeover;

  @override
  bool get busy => false;

  @override
  String errorText(BuildContext context, Object error) => 'takeover failed';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  Future<void> pumpCard(WidgetTester tester, _Takeover takeover) async {
    final host = _Host(takeover);
    await tester.pumpWidget(
      TestApp(
        child: IpingDashboardScope(
          host: host,
          child: const Scaffold(body: IpingNetworkTakeoverCard()),
        ),
      ),
    );
    addTearDown(host.dispose);
  }

  testWidgets('renders supported switches and persists a TUN toggle', (
    tester,
  ) async {
    final takeover = _Takeover();
    await pumpCard(tester, takeover);

    expect(find.text('System proxy'), findsOneWidget);
    expect(find.text('TUN'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(takeover.calls, ['tun:true']);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);
  });

  testWidgets('a router without system proxy shows only the TUN switch', (
    tester,
  ) async {
    await pumpCard(tester, _Takeover(supportsSystemProxy: false));

    expect(find.text('System proxy'), findsNothing);
    expect(find.text('TUN'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('a failed toggle reports the host error and keeps the value', (
    tester,
  ) async {
    final takeover = _Takeover()..failure = Exception('boom');
    await pumpCard(tester, takeover);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(takeover.calls, ['tun:true']);
    expect(find.text('takeover failed'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
  });
}
