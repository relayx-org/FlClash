import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/iping/support.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

final _image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMD'
  'EwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC',
);

Future<void> _pump(
  WidgetTester tester, {
  Future<Uint8List> Function()? load,
  required Future<void> Function(Uint8List) save,
}) async {
  await tester.pumpWidget(
    TestApp(
      child: Scaffold(
        body: IpingSupportDialog(load: load ?? () async => _image, save: save),
      ),
    ),
  );
  await tester.pump();
}

TextButton _saveButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save image'));

void main() {
  testWidgets('saving waits for the image and exports its original bytes', (
    tester,
  ) async {
    final loading = Completer<Uint8List>();
    Uint8List? saved;
    await _pump(
      tester,
      load: () => loading.future,
      save: (bytes) async => saved = bytes,
    );
    expect(_saveButton(tester).onPressed, isNull);

    loading.complete(_image);
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    await tester.tap(find.text('Save image'));
    await tester.pumpAndSettle();

    expect(saved, same(_image));
    expect(_saveButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active save prevents duplicate actions', (tester) async {
    final saving = Completer<void>();
    var calls = 0;
    await _pump(
      tester,
      save: (_) {
        calls++;
        return saving.future;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save image'));
    await tester.pump();

    final button = find.ancestor(
      of: find.byType(CommonCircleLoading),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    await tester.tap(button);
    expect(calls, 1);

    saving.complete();
    await tester.pumpAndSettle();
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a failed save reports the error and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      save: (_) async {
        if (++calls == 1) throw StateError('Save failed');
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save image'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to save the image. Try again.'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Save image'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Unable to save the image. Try again.'), findsNothing);
  });

  testWidgets('a failed image download can be retried before saving', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      load: () async {
        if (++calls == 1) throw StateError('Download failed');
        return _image;
      },
      save: (_) async {},
    );
    await tester.pumpAndSettle();
    expect(_saveButton(tester).onPressed, isNull);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('closing during a save ignores its late failure', (tester) async {
    final saving = Completer<void>();
    await _pump(tester, save: (_) => saving.future);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save image'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    saving.completeError(StateError('Save failed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
