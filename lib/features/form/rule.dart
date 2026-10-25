import 'package:fl_clash/state.dart';

export 'rule_form.dart';
export 'rule_item.dart';

const _ruleRowVerticalPadding = 7.0;

double get ruleItemHeight =>
    globalState.measure.listTitleHeight +
    globalState.measure.listSubtitleHeight +
    2 * _ruleRowVerticalPadding;
