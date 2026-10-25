import 'package:fl_clash/models/rule.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

class RuleItem extends StatelessWidget {
  static const _targetMaxWidthFactor = 0.5;
  static const _targetMinWidthFactor = 0.3;
  static const _labelTargetGap = 16.0;

  final bool isSelected;
  final bool isEditing;
  final Rule rule;
  final bool hasMatch;
  final void Function() onSelected;
  final void Function(Rule rule) onEdit;
  final String? Function(Rule rule)? invalidMessageOf;

  const RuleItem({
    super.key,
    required this.isSelected,
    required this.rule,
    required this.onSelected,
    required this.onEdit,
    this.invalidMessageOf,
    this.isEditing = false,
    this.hasMatch = false,
  });

  ({bool invalid, Color? color, String? message}) _checkInvalid(
    BuildContext context,
  ) {
    final message = invalidMessageOf?.call(rule);
    if (message == null && rule.ruleAction != RuleAction.SUB_RULE) {
      final ruleTarget = (rule.ruleTarget ?? '').toUpperCase();
      final color = switch (ruleTarget) {
        'DIRECT' || 'COMPATIBLE' => context.colorScheme.success,
        'REJECT' || 'REJECT-DROP' => context.colorScheme.warning,
        'PASS' || 'PASS-RULE' || 'GLOBAL' => context.colorScheme.tertiary,
        'MATCH' when hasMatch => context.colorScheme.tertiary,
        _ => null,
      };
      if (color != null) {
        return (invalid: false, color: color, message: null);
      }
    }
    final invalid = invalidMessageOf == null || message != null;
    return (
      invalid: invalid,
      color: invalid ? context.colorScheme.error : context.colorScheme.tertiary,
      message: message,
    );
  }

  Widget _buildInfoWidget(BuildContext context, String? message) {
    return CommonMinIconButtonTheme(
      child: IconButton(
        tooltip: AppLocalizations.of(context).tip,
        onPressed: () {
          showFloatingDialog<void>(
            context: context,
            child: CommonDialog(
              title: AppLocalizations.of(context).tip,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).confirm),
                ),
              ],
              child: Text(
                message ??
                    rule.targetErrorTip(
                      AppLocalizations.of(
                        context,
                      ).invalidSubRule(rule.subRule ?? ''),
                      AppLocalizations.of(
                        context,
                      ).invalidPolicy(rule.ruleTarget ?? ''),
                    ) ??
                    '',
              ),
            ),
          );
        },
        icon: GlyphIcon(
          AppGlyphs.info,
          fill: 1,
          size: 16.ap(context),
          color: context.colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkResult = _checkInvalid(context);
    final invalid = checkResult.invalid;
    return SelectedDecorationListItem(
      minVerticalPadding: 0,
      isSelected: isSelected,
      isEditing: isEditing,
      horizontalTitleGap: 0,
      invalid: invalid,
      onSelected: () {
        onSelected();
      },
      title: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelStyle = DefaultTextStyle.of(
              context,
            ).style.toJetBrainsMono;
            final painter = TextPainter(
              text: TextSpan(text: rule.ruleAction.name, style: labelStyle),
              textDirection: Directionality.of(context),
            )..layout();
            final actionWidth = painter.width;
            painter.dispose();
            final maxWidth = constraints.maxWidth;
            final targetMaxWidth = (maxWidth - _labelTargetGap - actionWidth)
                .clamp(
                  maxWidth * _targetMinWidthFactor,
                  maxWidth * _targetMaxWidthFactor,
                );
            return Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _RuleItemLabel(rule: rule, style: labelStyle),
                ),
                const SizedBox(width: _labelTargetGap),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: targetMaxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (invalid)
                        _buildInfoWidget(context, checkResult.message),
                      if (rule.realTarget != null)
                        Flexible(
                          child: TooltipText(
                            text: Text(
                              hasMatch &&
                                      rule.realTarget!.toUpperCase() ==
                                          RuleAction.MATCH.value
                                  ? AppLocalizations.of(context).matchTarget
                                  : rule.realTarget!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.subheadline
                                  .of(context)
                                  .toJetBrainsMono
                                  .copyWith(color: checkResult.color),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      onPressed: () {
        onEdit(rule);
      },
    );
  }
}

class _RuleItemLabel extends StatelessWidget {
  const _RuleItemLabel({required this.rule, required this.style});

  final Rule rule;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final content = rule.realContent ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rule.ruleAction.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        if (content.isNotEmpty)
          Flexible(
            child: TooltipText(
              text: Text(
                content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listSubtitleStyle.toJetBrainsMono.copyWith(
                  color: style.color?.opacity60,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RuleStatusItem extends StatelessWidget {
  final bool status;
  final Rule rule;
  final void Function(bool)? onChange;

  const RuleStatusItem({
    super.key,
    required this.status,
    required this.rule,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      title: TooltipText(
        text: Text(
          rule.rawValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.subheadline.of(context).toJetBrainsMono,
        ),
      ),
      trailing: Switch(value: status, onChanged: onChange),
      onPressed: onChange == null ? null : () => onChange!(!status),
    );
  }
}
