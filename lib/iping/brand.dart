import 'package:fl_clash/ui/ui.dart';
import 'brand_image_native.dart'
    if (dart.library.js_interop) 'brand_image_web.dart';
import 'package:material_ui/material_ui.dart';

class IpingLogo extends StatelessWidget {
  const IpingLogo({super.key, required this.src, this.size = 48});

  final String src;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: AppShape.all(AppCorner.fit(size))),
        child: SizedBox.square(
          dimension: size,
          child: loadBrandImage(
            src,
            Image.asset('assets/images/icon.png', package: brandAssetPackage),
          ),
        ),
      ),
    );
  }
}
