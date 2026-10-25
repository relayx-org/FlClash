import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class FilterRegexText extends StatelessWidget {
  final String regex;

  const FilterRegexText(this.regex, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      regex,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.footnote
          .of(context)
          .toJetBrainsMono
          .copyWith(color: context.colorScheme.tertiary),
    );
  }
}
