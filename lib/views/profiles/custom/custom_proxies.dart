import 'package:fl_clash/features/form/custom_proxy_editor.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/backend_resources.dart';
import 'package:fl_clash/iping/resource_controller.dart';
import 'package:fl_clash/iping/filters_page.dart';
import 'dart:async';
import 'package:fl_clash/state.dart';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart' hide FileInfo;
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quick_edit.dart';

class CustomProxiesView extends ConsumerStatefulWidget {
  const CustomProxiesView({super.key});

  @override
  ConsumerState createState() => _CustomProxiesViewState();
}

class _CustomProxiesViewState extends ConsumerState<CustomProxiesView> {
  late final ClashProvidersAction _providersAction;
  final _seenNames = <String>{};
  List<CustomProxy>? _opened;
  List<CustomProxy>? _latest;
  final _searchTexts = Expando<String>();
  var _query = SearchQuery('');
  var _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _providersAction = ref.read(clashProvidersActionProvider.notifier);
    ref.listenManual(customProxiesProvider, (_, next) {
      final proxies = next.value;
      if (proxies == null) {
        return;
      }
      _seenNames.addAll([for (final proxy in proxies) proxy.name]);
      _opened ??= proxies;
      _latest = proxies;
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    if (!customProxiesEquality.equals(_applied(_opened), _applied(_latest))) {
      unawaited(_providersAction.applyIfProxiesNamed(_seenNames));
    }
    super.dispose();
  }

  static List<CustomProxy> _applied(List<CustomProxy>? proxies) => [
    for (final proxy in proxies ?? const <CustomProxy>[])
      proxy.copyWith(emptyOptions: const {}),
  ];

  bool _resourceBusy = false;

  Future<bool> _mutateResources(
    Future<bool> Function(IpingResourceController<IpingCustomProxy, String>)
    mutation,
  ) async {
    if (_resourceBusy) return false;
    _resourceBusy = true;
    final controller = IpingResourceController<IpingCustomProxy, String>(
      ref.read(ipingBackendProvider).customProxies,
      keyOf: (item) => item.id,
    );
    try {
      return await globalState.safeRun(() async {
            if (!await controller.load()) {
              throw MessageException(controller.error.toString());
            }
            if (!await mutation(controller)) {
              throw MessageException(controller.error.toString());
            }
            return true;
          }) ??
          false;
    } finally {
      controller.dispose();
      _resourceBusy = false;
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final order = [
      for (final proxy
          in ref.read(customProxiesProvider).value ?? const <CustomProxy>[])
        proxy.id.toString(),
    ];
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= order.length ||
        newIndex >= order.length) {
      return;
    }
    order.insert(newIndex, order.removeAt(oldIndex));
    await _mutateResources((controller) => controller.reorderKeys(order));
  }

  void _handleSearch(String query) {
    setState(() {
      _query = SearchQuery(query);
    });
  }

  void _handleToggleSelected(int id) {
    setState(() {
      _selected = {..._selected}..addOrRemove(id);
    });
  }

  void _handleSelectAll(Set<int> ids) {
    setState(() {
      _selected = _selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDelete(Set<int> ids, {required Set<int> kept}) async {
    final appLocalizations = context.appLocalizations;
    final message = await _deleteMessage(
      ref,
      ids,
      appLocalizations.deleteMultipTip(appLocalizations.proxies),
    );
    if (!mounted) {
      return;
    }
    final res = await dialogs.showMessage(
      message: TextSpan(text: message),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !mounted) {
      return;
    }
    final removed = await _mutateResources(
      (controller) => controller.remove({for (final id in ids) id.toString()}),
    );
    if (removed && mounted) {
      setState(() => _selected = kept);
    }
  }

  Future<void> _handleQuickEdit() async {
    final previous = ref.read(customProxiesProvider).value;
    if (previous == null) {
      return;
    }
    final appLocalizations = context.appLocalizations;
    final core = ref.read(coreHandlerProvider);
    final List<String> links;
    try {
      links = await core.encodeShareLinks([
        for (final proxy in previous) proxy.definition,
      ]);
    } catch (error) {
      await dialogs.showMessage(message: TextSpan(text: compactError(error)));
      return;
    }
    if (!mounted) {
      return;
    }
    return showCustomQuickEdit(
      context,
      title: appLocalizations.proxies,
      content: ShareLinkEdit.textOf(links),
      schema: EditorSchema.shareLinks,
      invalidMessage: appLocalizations.shareLinksInvalid,
      apply: (content) async {
        final edit = ShareLinkEdit.read(
          content,
          previous: previous,
          links: links,
        );
        final decoded = await _decodeShareLinks(core, edit.pending);
        final dropped = edit.droppedLinks;
        final linked = dropped.isEmpty
            ? const <List<Map<String, dynamic>>>[]
            : await core.decodeShareLinks(dropped.values.toList());
        final proxies = edit.apply(
          decoded,
          groupNames: await ref.read(customGroupNamesProvider.future),
          linked: {
            for (final (index, id) in dropped.keys.indexed)
              if (linked[index] case [final definition]) id: definition,
          },
        );
        if (!await _confirmReplaced(previous, proxies)) {
          throw const QuickEditCancelled();
        }
        if (!await _mutateResources(
          (controller) => controller.replaceAll([
            for (final proxy in proxies) nativeIpingCustomProxy(proxy),
          ]),
        )) {
          throw const QuickEditCancelled();
        }
      },
    );
  }

  /// A line whose name changed is a new proxy: what custom profiles name the
  /// old one by is left missing, so the edit says which go and which come.
  Future<bool> _confirmReplaced(
    List<CustomProxy> previous,
    List<CustomProxy> next,
  ) async {
    final kept = {for (final proxy in next) proxy.id};
    final removed = [
      for (final proxy in previous)
        if (!kept.contains(proxy.id)) proxy.name,
    ];
    if (removed.isEmpty) {
      return true;
    }
    final existed = {for (final proxy in previous) proxy.id};
    final added = [
      for (final proxy in next)
        if (!existed.contains(proxy.id)) proxy.name,
    ];
    final appLocalizations = currentAppLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: added.isEmpty
            ? appLocalizations.proxiesRemovedTip(removed.join(', '))
            : appLocalizations.proxiesReplacedTip(
                removed.join(', '),
                added.join(', '),
              ),
      ),
      destructive: true,
    );
    return res == true;
  }

  void _handleAddOrUpdate({CustomProxy? proxy}) {
    showNestedFormSheet<CustomProxy>(
      context: context,
      profileId: null,
      overrides: [
        customProxyProvider.overrideWithBuild(
          (_, _) =>
              proxy ??
              const CustomProxy(id: -1, definition: {'name': '', 'type': 'ss'}),
        ),
      ],
      currentOf: (ref) => ref.read(customProxyProvider),
      formBuilder: (_) => const _EditCustomProxyView(),
    );
  }

  Widget _buildNode(
    CustomProxy proxy, {
    required Set<int> selected,
    required ItemPosition position,
    int? dragIndex,
  }) {
    final item = ItemPositionProvider(
      position: position,
      child: _NodeItem(
        proxy: proxy,
        isEditing: selected.isNotEmpty,
        isSelected: selected.contains(proxy.id),
        onSelected: () => _handleToggleSelected(proxy.id),
        onPressed: () => _handleAddOrUpdate(proxy: proxy),
      ),
    );
    if (dragIndex == null) {
      return KeyedSubtree(key: ValueKey(proxy.id), child: item);
    }
    return ReorderableDelayedDragStartListener(
      key: ValueKey(proxy.id),
      index: dragIndex,
      child: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final proxies = ref.watch(customProxiesProvider).value;
    final all = proxies ?? const <CustomProxy>[];
    final visible = all
        .whereMatches(
          _query,
          (proxy) => proxy.searchFields,
          texts: _searchTexts,
        )
        .toList();
    // Indices among the matches cannot be mapped back onto the full list.
    final reorderable = _query.isEmpty;
    final selected = _selected.intersection({
      for (final proxy in all) proxy.id,
    });
    final visibleIds = {for (final proxy in visible) proxy.id};
    final visibleSelected = selected.intersection(visibleIds);
    return CommonPopScope(
      onPop: selected.isEmpty
          ? null
          : (_) {
              setState(() {
                _selected = {};
              });
              return false;
            },
      child: CommonScaffold(
        title: appLocalizations.proxies,
        searchState: AppBarSearchState(onSearch: _handleSearch),
        actions: [
          if (selected.isEmpty)
            ListEditorAddAction(
              onAdd: _handleAddOrUpdate,
              onQuickEdit: _handleQuickEdit,
            ),
        ],
        selectionActions: selected.isEmpty
            ? const []
            : [
                IconButtonData(
                  glyph: AppGlyphs.delete,
                  onPressed: visibleSelected.isEmpty
                      ? null
                      : () => _handleDelete(
                          visibleSelected,
                          kept: selected.difference(visibleSelected),
                        ),
                  tooltip: appLocalizations.delete,
                ),
                IconButtonData(
                  glyph: AppGlyphs.selectAll,
                  onPressed: () => _handleSelectAll(visibleIds),
                  tooltip: appLocalizations.selectAll,
                ),
              ],
        body: NullStatusSwitcher(
          isLoading: proxies == null,
          isEmpty: visible.isEmpty,
          isSearching: _query.isNotEmpty,
          nullStatus: NullStatus(
            label: appLocalizations.nullTip(appLocalizations.proxies),
            illustration: NullStatusIllustration.proxies,
            action: TonalButton(
              size: TonalButtonSize.bar,
              glyph: AppGlyphs.addCircle,
              label: appLocalizations.add,
              onPressed: _handleAddOrUpdate,
            ),
          ),
          child: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: context.contentTopPadding),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + BottomInsetScope.of(context),
                  ),
                  sliver: reorderable
                      ? SliverReorderableList(
                          itemCount: visible.length,
                          itemBuilder: (_, index) => _buildNode(
                            visible[index],
                            selected: selected,
                            position: ItemPosition.get(index, visible.length),
                            dragIndex: index,
                          ),
                          proxyDecorator: (child, index, animation) =>
                              commonProxyDecorator(
                                _buildNode(
                                  visible[index],
                                  selected: selected,
                                  position: ItemPosition.get(
                                    index,
                                    visible.length,
                                  ),
                                  dragIndex: index,
                                ),
                                index,
                                animation,
                              ),
                          onReorderItem: _handleReorder,
                        )
                      : SliverList.builder(
                          itemCount: visible.length,
                          itemBuilder: (_, index) => _buildNode(
                            visible[index],
                            selected: selected,
                            position: ItemPosition.get(index, visible.length),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeItem extends ConsumerWidget {
  final CustomProxy proxy;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onPressed;

  const _NodeItem({
    required this.proxy,
    required this.isEditing,
    required this.isSelected,
    required this.onSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref
        .watch(
          customProxyListIssuesProvider.select(
            (state) => SelectValue(state[proxy.id] ?? const <CustomIssue>[]),
          ),
        )
        .value;
    return DecorationListItem(
      invalid: issues.isNotEmpty,
      isSelected: isSelected,
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      onPressed: isEditing ? onSelected : onPressed,
      title: EmojiText(
        proxy.name.isEmpty ? '-' : proxy.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(proxy.type, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (issues.isNotEmpty) CustomIssueButton(issues: issues),
          CommonCheckBox(
            value: isSelected,
            isCircle: true,
            onChanged: (_) => onSelected(),
          ),
        ],
      ),
    );
  }
}

Future<Map<int, List<Map<String, dynamic>>>> _decodeShareLinks(
  CoreController core,
  List<ShareLinkLine> lines,
) async {
  final appLocalizations = currentAppLocalizations;
  final results = await core.decodeShareLinks([
    for (final line in lines) line.link,
  ]);
  final decoded = <int, List<Map<String, dynamic>>>{};
  for (final (index, line) in lines.indexed) {
    if (results[index].isEmpty) {
      throw MessageException(
        appLocalizations.lineIssueTip(
          line.line,
          appLocalizations.shareLinksInvalid,
        ),
      );
    }
    decoded[line.line] = results[index];
  }
  final entries = [
    for (final MapEntry(key: line, value: proxies) in decoded.entries)
      for (final proxy in proxies) (line: line, proxy: proxy),
  ];
  final errors = await core.validateProxies([
    for (final entry in entries) entry.proxy,
  ]);
  for (final (index, error) in errors.indexed) {
    if (error.isNotEmpty) {
      throw MessageException(
        appLocalizations.lineIssueTip(entries[index].line, error),
      );
    }
  }
  return decoded;
}

/// Pops with what [read] made of the link, or with nothing when the link was
/// left as it came, which would only drop what the link cannot carry.
class _ShareLinkDialog extends StatefulWidget {
  final String initialLink;
  final Future<Map<String, dynamic>> Function(String link) read;

  const _ShareLinkDialog({required this.initialLink, required this.read});

  @override
  State<_ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends State<_ShareLinkDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLink);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final link = _controller.text.trim();
    if (link == widget.initialLink) {
      Navigator.of(context).pop();
      return;
    }
    if (_reading) {
      return;
    }
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final definition = await widget.read(link);
      if (mounted) {
        Navigator.of(context).pop(definition);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = compactError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.quickEdit,
      hasFields: true,
      actions: [
        TextButton(
          onPressed: _reading ? null : _submit,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: null,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: 'vless://…',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

Future<String> _deleteMessage(
  WidgetRef ref,
  Set<int> ids,
  String fallback,
) async {
  final names = {
    for (final proxy
        in ref.read(customProxiesProvider).value ?? const <CustomProxy>[])
      if (ids.contains(proxy.id)) proxy.name,
  };
  final users = await ref
      .read(profilesActionProvider.notifier)
      .proxyUsers(names);
  if (users.isEmpty) {
    return fallback;
  }
  return currentAppLocalizations.providerInUse(
    names.join(', '),
    users.map((profile) => profile.realLabel).join(', '),
  );
}

Future<bool> _handleSaveCustomProxy(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<String> onCoreRejected,
}) async {
  final proxy = ref.read(customProxyProvider);
  // A source still loading reads as empty below and would pass any name.
  Set<String> groupNames = const {};
  try {
    (_, groupNames) = await (
      ref.read(customProxiesProvider.future),
      ref.read(customGroupNamesProvider.future),
    ).wait;
  } catch (_) {}
  if (!context.mounted) {
    return false;
  }
  final issues = customProxyIssues(
    proxy,
    proxies: ref.read(customProxiesProvider).value ?? const [],
    groupNames: groupNames,
  );
  if (issues.isEmpty) {
    try {
      final error = await ref
          .read(ipingBackendProvider)
          .customProxies
          .validate(nativeIpingCustomProxy(proxy));
      if (error != null) issues.add(CustomIssue.coreRejected(error));
    } catch (error) {
      issues.add(CustomIssue.coreRejected(compactError(error)));
    }
  }
  if (!context.mounted) {
    return false;
  }
  // The form stays editable while the core checks the proxy.
  if (!identical(ref.read(customProxyProvider), proxy)) {
    return _handleSaveCustomProxy(context, ref, onCoreRejected: onCoreRejected);
  }
  if (issues.isNotEmpty) {
    if (issues case [CoreRejectedIssue(:final message)]) {
      onCoreRejected(message);
    }
    await showSaveBlocked(context, issues.getMessage(context));
    return false;
  }
  final saved = proxy.id == -1 ? proxy.copyWith(id: snowflake.id) : proxy;
  final controller = IpingResourceController<IpingCustomProxy, String>(
    ref.read(ipingBackendProvider).customProxies,
    keyOf: (item) => item.id,
  );
  try {
    if (!await controller.put(
      nativeIpingCustomProxy(saved),
      replacing: proxy.id == -1 ? null : proxy.id.toString(),
    )) {
      if (context.mounted) {
        await showSaveBlocked(
          context,
          resourceErrorMessage(
            controller.error,
            context.appLocalizations,
            label: context.appLocalizations.proxies,
          ),
        );
      }
      return false;
    }
  } finally {
    controller.dispose();
  }
  // The closing form would otherwise take its stored copy for another proxy
  // with its name.
  ref.read(customProxyProvider.notifier).value = saved;
  return true;
}

class _EditCustomProxyView extends ConsumerWidget {
  const _EditCustomProxyView();

  Future<Map<String, dynamic>?> _quickEdit(
    BuildContext context,
    WidgetRef ref,
    CustomProxy proxy,
  ) async {
    final l = context.appLocalizations;
    final core = ref.read(coreHandlerProvider);
    var link = '';
    try {
      link = (await core.encodeShareLinks([proxy.definition])).single;
    } catch (_) {}
    if (!context.mounted) return null;
    final definition = await dialogs.showCommonDialog<Map<String, dynamic>>(
      child: _ShareLinkDialog(
        initialLink: link,
        read: (text) async {
          final results = await core.decodeShareLinks([
            text,
            if (link.isNotEmpty) link,
          ]);
          final definitions = results.first;
          if (definitions.isEmpty) throw MessageException(l.shareLinksInvalid);
          if (definitions.length > 1) {
            throw MessageException(l.singleShareLinkOnly);
          }
          return withUnlinkedFields(
            definitions.single,
            previous: ref.read(customProxyProvider).definition,
            linked: results.skip(1).firstOrNull?.singleOrNull,
          );
        },
      ),
    );
    if (definition == null || !context.mounted) return null;
    final current = ref.read(customProxyProvider);
    if ((definition['name'] ?? '') == '' && current.name.isNotEmpty) {
      return {...definition, 'name': current.name};
    }
    return importedCustomProxies(
      [definition],
      groupNames: ref.read(customGroupNamesProvider).value ?? const {},
      existing: [
        for (final item in ref.read(customProxiesProvider).value ?? [])
          if (item.id != current.id) item,
      ],
    ).single.definition;
  }

  Future<bool> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.appLocalizations;
    final id = ref.read(customProxyProvider).id;
    final message = await _deleteMessage(ref, {id}, l.deleteTip(l.proxies));
    if (!context.mounted) return false;
    if (await dialogs.showMessage(
              message: TextSpan(text: message),
              destructive: true,
              confirmText: l.delete,
            ) !=
            true ||
        !context.mounted) {
      return false;
    }
    final controller = IpingResourceController<IpingCustomProxy, String>(
      ref.read(ipingBackendProvider).customProxies,
      keyOf: (item) => item.id,
    );
    try {
      final saved = await controller.remove({id.toString()});
      if (!saved && context.mounted) {
        await showSaveBlocked(
          context,
          resourceErrorMessage(controller.error, l, label: l.proxies),
        );
      }
      return saved;
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxy = ref.watch(customProxyProvider);
    final issues = customProxyIssues(
      proxy,
      proxies: ref.watch(customProxiesProvider).value ?? const [],
      groupNames: ref.watch(customGroupNamesProvider).value ?? const {},
    );
    return IpingCustomProxyEditor(
      proxy: proxy,
      isNew: proxy.id == -1,
      onChanged: (value) =>
          ref.read(customProxyProvider.notifier).value = value,
      validate: (value) => ref
          .read(ipingBackendProvider)
          .customProxies
          .validate(nativeIpingCustomProxy(value)),
      save: (onRejected) =>
          _handleSaveCustomProxy(context, ref, onCoreRejected: onRejected),
      showSaveProgress: false,
      close: () => context.safeNestedPop(),
      bindSave: (save) => NestedFormSheet.bindSave(context, save),
      quickEdit: (value) => _quickEdit(context, ref, value),
      delete: () => _delete(context, ref),
      nameInvalid: issues.any(
        (issue) =>
            issue is EmptyNameIssue ||
            issue is ReservedNameIssue ||
            issue is DuplicateNameIssue,
      ),
      issuesBuilder: (context, error, submitted) => CustomIssuesBanner(
        issues: [...issues, if (error != null) CustomIssue.coreRejected(error)]
            .where(
              (issue) => proxy.id != -1 || submitted || !issue.isIncomplete,
            )
            .toList(),
      ),
    );
  }
}
