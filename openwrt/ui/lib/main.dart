import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' show FrameTiming;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'client_web.dart';

@JS('ipingDiagnosticsEnabled')
external JSBoolean? get _diagnosticsEnabled;

@JS('ipingRecordFrame')
external void _recordFrame(JSNumber build, JSNumber raster, JSNumber total);

void main() {
  if (_diagnosticsEnabled?.toDart ?? false) {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    void record(List<FrameTiming> timings) {
      for (final timing in timings) {
        _recordFrame(
          (timing.buildDuration.inMicroseconds / 1000).toJS,
          (timing.rasterDuration.inMicroseconds / 1000).toJS,
          (timing.totalSpan.inMicroseconds / 1000).toJS,
        );
      }
    }

    binding.addTimingsCallback(record);
    Timer(const Duration(seconds: 65), () {
      binding.removeTimingsCallback(record);
    });
  }
  runApp(
    DefaultAssetBundle(
      bundle: _SharedAssets(),
      child: const RouterApp(client: WebRouterClient()),
    ),
  );
}

class _SharedAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/fl_clash/$key' : key,
  );
}
