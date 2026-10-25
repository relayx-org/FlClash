import 'package:material_ui/material_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../common/log_payload.dart';
import '../l10n/l10n.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';
import '../ui/record.dart';

class LogRecord {
  const LogRecord({
    required this.dateTime,
    required this.level,
    required this.payload,
  });
  final String dateTime;
  final String level;
  final String payload;
}

class LogsPage extends StatelessWidget {
  const LogsPage({
    super.key,
    required this.controller,
    required this.physics,
    required this.count,
    required this.itemBuilder,
    required this.timestampAt,
    required this.searching,
    required this.following,
    required this.onSearch,
    required this.onKeywords,
    required this.onPause,
    required this.onResume,
    required this.onExport,
    this.loading = false,
    this.error,
  });
  final ScrollController controller;
  final ScrollPhysics physics;
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final String Function(int) timestampAt;
  final bool searching;
  final bool following;
  final bool loading;
  final String? error;
  final ValueChanged<String> onSearch;
  final ValueChanged<List<String>> onKeywords;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.logs,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.export,
          tooltip: l.exportLogs,
          onPressed: onExport,
        ),
      ],
      onKeywordsUpdate: onKeywords,
      searchState: AppBarSearchState(onSearch: onSearch),
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: loading,
          isEmpty: count == 0,
          isSearching: searching,
          nullStatus: NullStatus(
            illustration: NullStatusIllustration.logs,
            label: error ?? l.nullTip(l.logs),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: FloatingScrollbar(
              controller: controller,
              hintBuilder: (fraction) => count == 0
                  ? ''
                  : timestampAt((fraction * (count - 1)).round()),
              child: ScrollToEndBox(
                onCancelToEnd: onPause,
                onResumeToEnd: onResume,
                controller: controller,
                enable: following,
                child: SuperListView.separated(
                  physics: physics,
                  reverse: true,
                  shrinkWrap: true,
                  controller: controller,
                  padding: EdgeInsets.only(
                    top: context.contentTopPadding,
                    bottom: 16 + BottomInsetScope.of(context),
                  ),
                  itemCount: count,
                  extentEstimation: recordListExtentEstimation,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: recordListGap),
                  itemBuilder: itemBuilder,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LogRecordItem extends StatelessWidget {
  final LogRecord log;
  final Function(String)? onClick;

  const LogRecordItem({super.key, required this.log, this.onClick});

  @override
  Widget build(BuildContext context) {
    final tone = switch (log.level) {
      'warning' => RecordTone.warning,
      'error' => RecordTone.error,
      _ => RecordTone.neutral,
    };
    final payload = LogPayload.parse(log.payload);
    return RecordListItem(
      onTap: () {},
      header: RecordHeader(
        children: [
          RecordTimestamp(log.dateTime),
          RecordLabel(
            label: log.level,
            tone: tone,
            onPressed: () => onClick?.call(log.level),
          ),
        ],
      ),
      body: _LogBody(payload: payload, errorColor: tone.accentColor(context)),
    );
  }
}

class _LogBody extends StatelessWidget {
  final LogPayload payload;
  final Color? errorColor;

  const _LogBody({required this.payload, this.errorColor});

  String get _sourceText => [
    payload.tag,
    if (payload.route case final route?) ...[route.source, route.sourceDetail],
  ].where((text) => text.isNotEmpty).join('  ·  ');

  @override
  Widget build(BuildContext context) {
    final styles = RecordTextStyles.of(context);
    final route = payload.route;
    if (route == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(payload.message, style: styles.primary),
          if (payload.tag.isNotEmpty)
            Text(payload.tag, style: styles.secondary),
        ],
      );
    }
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(text: route.destination, style: styles.title),
          if (route.error.isNotEmpty)
            TextSpan(
              text: '\n${route.error}',
              style: styles.secondary.copyWith(color: errorColor),
            ),
          const TextSpan(text: '\n'),
          if (route.rule.isNotEmpty) ...[
            TextSpan(text: route.rule, style: styles.secondary),
            TextSpan(text: ' \u2192 ', style: styles.secondary.toJetBrainsMono),
          ],
          TextSpan(
            text: route.proxy,
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .copyWith(color: context.colorScheme.primary),
          ),
          TextSpan(text: '\n$_sourceText', style: styles.secondary),
        ],
      ),
    );
  }
}
