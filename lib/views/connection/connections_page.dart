import 'package:material_ui/material_ui.dart';

import '../../enum/page_label.dart';
import '../../l10n/l10n.dart';
import '../../l10n/page_labels.dart';
import '../../models/tracker.dart';
import '../../features/connection/connection.dart';
import '../../ui/icons/icons.dart';
import '../../ui/ui.dart';
import '../../ui/record_table.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.loaded,
    required this.onClose,
    required this.onCloseAll,
  });
  final TrackerInfoListController controller;
  final ScrollController scrollController;
  final bool loaded;
  final ValueChanged<String> onClose;
  final VoidCallback onCloseAll;
  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    return CommonScaffold(
      title: PageLabel.connections.labelOf(appLocalizations),
      onKeywordsUpdate: controller.updateKeywords,
      searchState: AppBarSearchState(onSearch: controller.search),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.clearAll,
          tooltip: appLocalizations.closeConnections,
          onPressed: onCloseAll,
        ),
      ],
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: controller,
        builder: (context, state, _) {
          final connections = state.list;
          Widget buildAction(TrackerInfo trackerInfo) {
            return _BlockConnectionButton(
              onPressed: () {
                onClose(trackerInfo.id);
              },
            );
          }

          return NullStatusSwitcher(
            isLoading: !loaded,
            isEmpty: connections.isEmpty,
            isSearching: state.isSearching,
            nullStatus: NullStatus(
              label: appLocalizations.nullTip(appLocalizations.connections),
              illustration: NullStatusIllustration.connections,
            ),
            child: RecordTableFrame<TrackerInfo>(
              tableId: 'connections',
              items: connections,
              columnsOf: (width) => trackerInfoColumns(
                context,
                width: width,
                isLive: true,
                actionBuilder: buildAction,
              ),
              builder: (context, table, connections) => TrackerInfoAnimatedList(
                controller: scrollController,
                padding: EdgeInsets.only(
                  top: context.contentTopPadding,
                  bottom: 16 + BottomInsetScope.of(context),
                ),
                trackerInfos: connections,
                table: table,
                detailTitle: appLocalizations.details(
                  appLocalizations.connection,
                ),
                actionBuilder: buildAction,
              ),
            ),
          );
        },
      ),
    );
  }
}

// One per live row: an IconButton would add a theme animation to each.
class _BlockConnectionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BlockConnectionButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context).blockConnection,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onPressed,
          customBorder: AppShape.circle,
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: GlyphIcon(
                AppGlyphs.block,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
