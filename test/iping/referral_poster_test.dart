import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fl_clash/iping/referral_poster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

const _link = 'https://iping.my?ref=7';

final _preview = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFUlEQVR4nGP8//8/AwMD'
  'EwMDA4ICADkbAwP+wj6MAAAAAElFTkSuQmCC',
);

void main() {
  testWidgets('the poster composites the referral link into its frame', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => composeReferralPoster(_link));
    expect(bytes, isNotNull);

    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      return (await codec.getNextFrame()).image;
    });
    expect(image!.width, 1024);
    expect(image.height, 1536);

    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final pixels = data!.buffer.asUint8List();
    bool isDark(int x, int y) {
      final index = (y * image.width + x) * 4;
      return pixels[index] < 40 &&
          pixels[index + 1] < 40 &&
          pixels[index + 2] < 40;
    }

    var dark = 0;
    for (var y = 1136; y < 1360; y++) {
      for (var x = 751; x < 975; x++) {
        if (isDark(x, y)) dark++;
      }
    }
    expect(dark, greaterThan(100));
    expect(dark, lessThan(224 * 224 * 0.4));

    final mark = (1141 * image.width + 760) * 4;
    expect(pixels[mark], greaterThan(240));
    expect(pixels[mark + 1], greaterThan(240));
    expect(pixels[mark + 2], greaterThan(240));

    final sky = (1450 * image.width + 100) * 4;
    expect(pixels[sky + 2], greaterThan(pixels[sky]));

    expect(
      identical(
        bytes,
        await tester.runAsync(() => composeReferralPoster(_link)),
      ),
      isTrue,
    );
  });

  testWidgets('the share sheet previews the poster and shares the same bytes', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      TestApp(
        withStatusManager: true,
        wrapInProviderScope: true,
        child: IpingReferralShareSheet(
          link: _link,
          compose: (_) async => _preview,
          share: (bytes, {required name, text, origin}) async {
            calls.add('$name|$text|${bytes.length}');
            return true;
          },
          save: (_) async => true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image, skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Share image'));
    await tester.pump();

    expect(calls, ['iping-referral.png|$_link|${_preview.length}']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed composition reports and retries', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      TestApp(
        withStatusManager: true,
        wrapInProviderScope: true,
        child: IpingReferralShareSheet(
          link: _link,
          compose: (_) async {
            attempts++;
            if (attempts == 1) throw Exception('unavailable');
            return _preview;
          },
          share: (_, {required name, text, origin}) async => true,
          save: (_) async => true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to share the image. Try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(Image, skipOffstage: false), findsOneWidget);
  });
}
