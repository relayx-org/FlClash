import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'list_presentation.dart';
import 'common.dart';

export 'list_presentation.dart' show ProxyGroupHeader;

typedef ListHeader = ProxyGroupHeader;

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);
    final style = ref.watch(proxiesStyleSettingProvider);
    ref.watch(themeSettingProvider.select((state) => state.textScale));
    final groups = state.groups;
    return ProxyGroupsList(
      itemHeight: getItemHeight(state.proxyCardType),
      layout: style.layout,
      iconStyle: style.iconStyle,
      searching: SearchQuery(
        ref.watch(queryProvider(QueryTag.proxies)),
      ).isNotEmpty,
      gap: cardSpacingOf(context, ref.watch(viewModeProvider)),
      groups: [
        for (final group in groups)
          ProxyGroupPresentation(
            name: group.name,
            type: group.type.name,
            count: group.all.length,
            identity: group,
            expanded: !state.currentFoldSet.contains(group.name),
            selectedName:
                ref.watch(selectedProxyNameProvider(group.name)) ?? '',
            testing: ref.watch(
              delayTestingGroupsProvider.select(
                (state) => state.contains(group.name),
              ),
            ),
            selectedIndex: () {
              final selected = ref.read(selectedProxyNameProvider(group.name));
              final index = group.all.indexWhere(
                (proxy) => proxy.name == selected,
              );
              return index < 0 ? null : index;
            },
            itemBuilder: (_, index) => ProxyCard(
              key: ValueKey('${group.name}.${group.all[index].name}'),
              groupName: group.name,
              testUrl: group.testUrl,
              proxy: group.all[index],
              groupType: group.type,
              type: state.proxyCardType,
            ),
            iconBuilder: (_) => CommonTargetIcon(
              src: group.icon,
              fallback: GroupMonogram(group.name),
            ),
            onToggle: () {
              final folded = Set<String>.from(ref.read(foldSetProvider));
              if (!folded.remove(group.name)) folded.add(group.name);
              ref
                  .read(proxiesActionProvider.notifier)
                  .updateCurrentFoldSet(folded);
            },
            onTest: () => ref
                .read(proxiesActionProvider.notifier)
                .delayTestPageGroup(group.name),
          ),
      ],
    );
  }
}
