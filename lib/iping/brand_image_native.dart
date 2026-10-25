import 'package:material_ui/material_ui.dart';

import '../widgets/icon.dart';

const String? brandAssetPackage = null;

Widget loadBrandImage(String src, Widget fallback) =>
    CommonTargetIcon(src: src, fallback: fallback);
