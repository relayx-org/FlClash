import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'text.dart';
import 'measure.dart';
import 'selection_mark.dart';
import 'shape.dart';
import 'typography.dart';
import 'color.dart';

class ProxyNodeCard extends StatelessWidget {
  const ProxyNodeCard({
    super.key,
    required this.name,
    required this.description,
    required this.compact,
    required this.loose,
    required this.inUse,
    required this.pinned,
    required this.latency,
    this.onPressed,
  });
  final String name;
  final String description;
  final bool compact;
  final bool loose;
  final bool inUse;
  final bool pinned;
  final Widget latency;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.footnote
        .of(context)
        .copyWith(
          overflow: TextOverflow.ellipsis,
          color: Theme.of(context).colorScheme.onSurface.opacity80,
        );
    final descriptionView = SizedBox(
      height: MeasureScope.of(context).textHeight(AppTextStyle.footnote),
      child: loose
          ? EmojiText(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            )
          : TooltipText(text: Text(description, maxLines: 1, style: style)),
    );
    return ProxyCardFrame(
      name: name,
      compact: compact,
      inUse: inUse,
      pinned: pinned,
      onPressed: onPressed,
      details: loose
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [descriptionView, const SizedBox(height: 6), latency],
            )
          : SizedBox(
              height: MeasureScope.of(
                context,
              ).textHeight(AppTextStyle.footnote),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: descriptionView),
                  latency,
                ],
              ),
            ),
    );
  }
}

double proxyCardHeight(
  Measure measure, {
  required bool compact,
  bool loose = false,
}) {
  final base =
      28 +
      measure.textHeight(AppTextStyle.subheadline) * 2 +
      measure.textHeight(AppTextStyle.footnote);
  if (loose) return base + measure.textHeight(AppTextStyle.caption2) + 6;
  return compact ? base - measure.textHeight(AppTextStyle.subheadline) : base;
}

class ProxyCardFrame extends StatelessWidget {
  const ProxyCardFrame({
    super.key,
    required this.name,
    required this.compact,
    required this.inUse,
    required this.pinned,
    required this.details,
    this.onPressed,
  });

  final String name;
  final bool compact;
  final bool inUse;
  final bool pinned;
  final Widget details;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
    radius: AppCorner.lg,
    enterActionsOnRight: true,
    onPressed: onPressed,
    isSelected: inUse,
    child: Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Expanded(
                child: SizedBox(
                  height:
                      MeasureScope.of(
                        context,
                      ).textHeight(AppTextStyle.subheadline) *
                      (compact ? 1 : 2),
                  child: EmojiText(
                    name,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline.of(context),
                  ),
                ),
              ),
              if (pinned)
                SelectionBadge.preferred(inUse: inUse)
              else if (inUse)
                const SelectionBadge(),
            ],
          ),
          const SizedBox(height: 8),
          details,
        ],
      ),
    ),
  );
}
