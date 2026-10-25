import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Backend extends Mock implements IpingBackend {}

Future<ProviderContainer> _openPortForm(
  WidgetTester tester, {
  IpingBackend? backend,
}) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(TestProfiles.new),
      if (backend != null) ipingBackendProvider.overrideWithValue(backend),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container
      .read(viewSizeProvider.notifier)
      .update((_) => const Size(1000, 900));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        child: Scaffold(body: ListView(children: const [PortItem()])),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.byType(PortItem));
  await tester.pumpAndSettle();
  return container;
}

Finder get _fields => find.byType(TextFormField);

Finder _banner(String text) => find.descendant(
  of: find.byType(ErrorBanner),
  matching: find.textContaining(text),
);

void main() {
  testWidgets('opens with every port filled in', (tester) async {
    final container = await _openPortForm(tester);
    final config = container.read(patchClashConfigProvider);

    expect(_fields, findsNWidgets(5));
    expect(
      [
        for (final field in tester.widgetList<TextFormField>(_fields))
          field.controller?.text,
      ],
      [
        for (final port in [
          config.mixedPort,
          config.port,
          config.socksPort,
          config.redirPort,
          config.tproxyPort,
        ])
          '$port',
      ],
    );
    expect(
      tester
          .widget<ErrorBanner>(find.byType(ErrorBanner, skipOffstage: false))
          .message,
      isNull,
    );
  });

  testWidgets('rejects a mixed port outside the allowed range', (tester) async {
    await _openPortForm(tester);

    await tester.enterText(_fields.first, '80');
    await tester.pumpAndSettle();

    expect(_banner('1024'), findsOneWidget);
  });

  testWidgets('rejects zero for the mixed port but accepts it elsewhere', (
    tester,
  ) async {
    await _openPortForm(tester);

    await tester.enterText(_fields.at(1), '0');
    await tester.pumpAndSettle();
    expect(_banner('1024'), findsNothing);

    await tester.enterText(_fields.first, '0');
    await tester.pumpAndSettle();
    expect(_banner('1024'), findsOneWidget);
  });

  testWidgets('reports a conflict when two ports share a value', (
    tester,
  ) async {
    await _openPortForm(tester);

    await tester.enterText(_fields.first, '7890');
    await tester.enterText(_fields.at(1), '7890');
    await tester.pumpAndSettle();

    expect(_banner('Please enter a different port'), findsOneWidget);

    await tester.enterText(_fields.at(1), '07890');
    await tester.pumpAndSettle();

    expect(_banner('Please enter a different port'), findsOneWidget);
  });

  testWidgets('an invalid port keeps the form open and writes nothing', (
    tester,
  ) async {
    final container = await _openPortForm(tester);
    final before = container.read(patchClashConfigProvider);

    await tester.enterText(_fields.first, '80');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(_fields, findsNWidgets(5));
    expect(container.read(patchClashConfigProvider), before);
  });

  testWidgets('saving valid ports writes them to the patch config', (
    tester,
  ) async {
    final container = await _openPortForm(tester);

    await tester.enterText(_fields.first, '7891');
    await tester.enterText(_fields.at(1), '7892');
    await tester.enterText(_fields.at(2), '7893');
    await tester.enterText(_fields.at(3), '0');
    await tester.enterText(_fields.at(4), '0');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(_fields, findsNothing);
    final config = container.read(patchClashConfigProvider);
    expect(config.mixedPort, 7891);
    expect(config.port, 7892);
    expect(config.socksPort, 7893);
    expect(config.redirPort, 0);
    expect(config.tproxyPort, 0);
  });

  testWidgets('a backend failure keeps ports editable and allows retry', (
    tester,
  ) async {
    final backend = _Backend();
    when(() => backend.updateSettings(any())).thenThrow(
      const IpingSettingsException('port', IpingSettingsIssue.portConflict),
    );
    final container = await _openPortForm(tester, backend: backend);
    final before = container.read(patchClashConfigProvider);
    await tester.enterText(_fields.first, '7900');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(_fields, findsNWidgets(5));
    expect(_banner('Please enter a different port'), findsOneWidget);
    expect(container.read(patchClashConfigProvider), before);
    when(() => backend.updateSettings(any())).thenAnswer((_) async {});
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(_fields, findsNothing);
    verify(
      () => backend.updateSettings({
        'mixed-port': 7900,
        'port': 0,
        'socks-port': 0,
        'redir-port': 0,
        'tproxy-port': 0,
      }),
    ).called(2);
  });
}
