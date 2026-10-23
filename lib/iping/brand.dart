import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/icon.dart';
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
          child: CommonTargetIcon(
            src: src,
            fallback: Image.asset('assets/images/icon.png'),
          ),
        ),
      ),
    );
  }
}
