import 'package:material_ui/material_ui.dart';

const brandAssetPackage = 'fl_clash';

Widget loadBrandImage(String src, Widget fallback) => src.isEmpty
    ? fallback
    : Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
