import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'client_web.dart';

void main() {
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
