import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/confirmation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'providers.dart';
import 'store_widgets.dart';
import 'topup.dart';
import 'tunnel.dart';
import 'tunnel_export.dart';
import 'tunnel_probe.dart';

enum _TunnelFilter { all, active, inactive, expired }

const _tunnelTypes = [
  'tcp',
  'mtcp',
  'udp',
  'relayx',
  'wss',
  'mwss',
  'tls',
  'mtls',
];

const _sectionGap = SizedBox(height: 24);
const _tunnelGlyph = GlyphIcon(AppGlyphs.swap);

String tunnelTypeLabel(AppLocalizations l, String type) => switch (type) {
  'tcp' => l.ipingTunnelTypeTcp,
  'mtcp' => l.ipingTunnelTypeMtcp,
  'udp' => l.ipingTunnelTypeUdp,
  'relayx' => l.ipingTunnelTypeRelayx,
  'wss' => l.ipingTunnelTypeWss,
  'mwss' => l.ipingTunnelTypeMwss,
  'tls' => l.ipingTunnelTypeTls,
  'mtls' => l.ipingTunnelTypeMtls,
  _ => type,
};

String tunnelRateLabel(num rate) =>
    rate == rate.roundToDouble() ? rate.toInt().toString() : rate.toString();

String _filterLabel(AppLocalizations l, _TunnelFilter filter) =>
    switch (filter) {
      _TunnelFilter.all => l.ipingTunnelFilterAll,
      _TunnelFilter.active => l.ipingTunnelStatusActive,
      _TunnelFilter.inactive => l.ipingTunnelStatusInactive,
      _TunnelFilter.expired => l.ipingTunnelExpired,
    };

String _ipTypeLabel(AppLocalizations l, String? ipType) => switch (ipType) {
  'v4' => 'IPv4',
  'v6' => 'IPv6',
  _ => l.ipingTunnelFilterAll,
};

String _switchLabel(AppLocalizations l, bool? value, {required String unset}) =>
    switch (value) {
      true => l.ipingTunnelFilterAutoRenewOn,
      false => l.ipingTunnelFilterAutoRenewOff,
      null => unset,
    };

String _failureText(
  AppLocalizations l,
  Object error, {
  required String fallback,
}) {
  if (error is IpingException) {
    if (error.failure == IpingFailure.session) return l.ipingSessionExpired;
    final message = error.message;
    if (message != null && message.isNotEmpty) return message;
  }
  return fallback;
}

class IpingTunnelsPage extends ConsumerStatefulWidget {
  const IpingTunnelsPage({super.key, this.pageSize = 100});

  final int pageSize;

  @override
  ConsumerState<IpingTunnelsPage> createState() => _IpingTunnelsPageState();
}

class _IpingTunnelsPageState extends ConsumerState<IpingTunnelsPage> {
  String _query = '';
  _TunnelFilter _filter = _TunnelFilter.all;
  String? _tunnelType;
  bool? _autoRenew;
  String? _ipType;
  int? _listenPort;
  IpingTunnelPage? _data;
  Object? _error;
  var _loading = true;
  var _loadingMore = false;
  var _loadedPages = 1;
  var _token = 0;
  final _selectedIds = <int>{};
  var _selectionMode = false;

  IpingTunnelQuery _request({int page = 1}) => IpingTunnelQuery(
    name: _query,
    status: switch (_filter) {
      _TunnelFilter.active => 'active',
      _TunnelFilter.inactive => 'inactive',
      _ => null,
    },
    expired: switch (_filter) {
      _TunnelFilter.active || _TunnelFilter.inactive => false,
      _TunnelFilter.expired => true,
      _TunnelFilter.all => null,
    },
    tunnelType: _tunnelType,
    autoRenew: _autoRenew,
    ipType: _ipType,
    listenPort: _listenPort,
    page: page,
    perPage: widget.pageSize,
  );

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  Future<void> _reload({bool initial = false}) async {
    final token = ++_token;
    if (!initial && mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
      });
    }
    try {
      final page = await ref
          .read(ipingAuthenticatedApiProvider)
          .tunnels(_request());
      if (!mounted || token != _token) return;
      setState(() {
        _data = page;
        _loadedPages = 1;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _token) return;
      setState(() {
        _data = null;
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _loadMore() async {
    final data = _data;
    if (data == null || _loadingMore || !data.hasMore) return;
    final token = _token;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(ipingAuthenticatedApiProvider)
          .tunnels(_request(page: _loadedPages + 1));
      if (!mounted || token != _token) return;
      setState(() {
        _data = data.append(page);
        _loadedPages += 1;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || token != _token) return;
      setState(() => _loadingMore = false);
      context.showNotifier(
        _failureText(
          context.appLocalizations,
          error,
          fallback: context.appLocalizations.ipingTunnelsLoadFailed,
        ),
        level: MessageLevel.error,
      );
    }
  }

  void _search(String query) {
    if (query == _query) return;
    setState(() => _query = query);
    _reload();
  }

  void _select(_TunnelFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _reload();
  }

  void _selectType(String? type) {
    if (type == _tunnelType) return;
    setState(() => _tunnelType = type);
    _reload();
  }

  void _selectAutoRenew(bool? autoRenew) {
    if (autoRenew == _autoRenew) return;
    setState(() => _autoRenew = autoRenew);
    _reload();
  }

  void _selectIpType(String? ipType) {
    if (ipType == _ipType) return;
    setState(() => _ipType = ipType);
    _reload();
  }

  void _selectListenPort(int? port) {
    if (port == _listenPort) return;
    setState(() => _listenPort = port);
    _reload();
  }

  void _resetFilters() {
    if (_filter == _TunnelFilter.all &&
        _tunnelType == null &&
        _autoRenew == null &&
        _ipType == null &&
        _listenPort == null) {
      return;
    }
    setState(() {
      _filter = _TunnelFilter.all;
      _tunnelType = null;
      _autoRenew = null;
      _ipType = null;
      _listenPort = null;
    });
    _reload();
  }

  Future<void> _openFilterSheet() async {
    await showInSheet<void>(
      context,
      builder: (_) => _TunnelFilterSheet(
        filter: _filter,
        tunnelType: _tunnelType,
        autoRenew: _autoRenew,
        ipType: _ipType,
        listenPort: _listenPort,
        onApply: (filter, tunnelType, autoRenew, ipType, listenPort) {
          setState(() {
            _filter = filter;
            _tunnelType = tunnelType;
            _autoRenew = autoRenew;
            _ipType = ipType;
            _listenPort = listenPort;
          });
          _reload();
        },
      ),
    );
  }

  bool _matches(IpingTunnel tunnel) {
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      final matchesName = tunnel.name.toLowerCase().contains(query);
      final matchesPort =
          tunnel.listenPort != null && '${tunnel.listenPort}'.contains(query);
      final matchesForward = tunnel.forwardAddresses.keys.any(
        (address) => address.toLowerCase().contains(query),
      );
      if (!matchesName && !matchesPort && !matchesForward) {
        return false;
      }
    }
    if (_tunnelType != null && tunnel.type != _tunnelType) {
      return false;
    }
    if (_autoRenew != null && tunnel.autoRenew != _autoRenew) {
      return false;
    }
    if (_ipType != null && tunnel.ipType != _ipType) {
      return false;
    }
    if (_listenPort != null && tunnel.listenPort != _listenPort) {
      return false;
    }
    return switch (_filter) {
      _TunnelFilter.all => true,
      _TunnelFilter.active => tunnel.enabled && !tunnel.isExpired,
      _TunnelFilter.inactive => !tunnel.enabled && !tunnel.isExpired,
      _TunnelFilter.expired => tunnel.isExpired,
    };
  }

  void _replace(IpingTunnel tunnel) {
    final data = _data;
    if (data == null) return;
    final items = [...data.items];
    final index = items.indexWhere((item) => item.id == tunnel.id);
    if (index < 0) return;
    var total = data.total;
    if (_matches(tunnel)) {
      items[index] = tunnel;
    } else {
      items.removeAt(index);
      if (total > 0) total -= 1;
    }
    setState(() => _data = IpingTunnelPage(items: items, total: total));
  }

  Future<void> _open(IpingTunnel tunnel) async {
    await showInSheet<void>(
      context,
      builder: (_) =>
          IpingTunnelDetailPage(tunnel: tunnel, onChanged: _replace),
    );
  }

  Future<void> _openEdit(IpingTunnel tunnel) async {
    await showInSheet<void>(
      context,
      builder: (_) => IpingTunnelEditPage(tunnel: tunnel, onChanged: _replace),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }

  void _enterSelectionMode([int? id]) {
    setState(() {
      _selectionMode = true;
      if (id != null) {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<IpingTunnel> items) {
    setState(() {
      final allIds = items.map((t) => t.id).toSet();
      if (_selectedIds.containsAll(allIds) && allIds.isNotEmpty) {
        _selectedIds.removeAll(allIds);
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _openBatchRenew(List<IpingTunnel> selected) async {
    final changed = await showInSheet<bool>(
      context,
      builder: (_) => _BatchRenewSheet(tunnels: selected),
    );
    if (changed == true && mounted) {
      context.showNotifier(
        context.appLocalizations.ipingTunnelBatchRenewSuccess(selected.length),
        level: MessageLevel.success,
      );
      _exitSelectionMode();
      await _reload();
    }
  }

  Future<void> _openBatchUpdate(List<IpingTunnel> selected) async {
    final changed = await showInSheet<bool>(
      context,
      builder: (_) => _BatchUpdateSheet(tunnels: selected),
    );
    if (changed == true && mounted) {
      context.showNotifier(
        context.appLocalizations.ipingTunnelBatchUpdateSuccess,
        level: MessageLevel.success,
      );
      _exitSelectionMode();
      await _reload();
    }
  }

  Future<void> _batchCopyAddresses(List<IpingTunnel> selected) async {
    final l = context.appLocalizations;
    final addresses = selected.expand((t) => t.listenAddresses).toList();
    if (addresses.isEmpty) {
      context.showNotifier(
        l.ipingTunnelBatchCopyEmpty,
        level: MessageLevel.warning,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: addresses.join('\n')));
    if (!mounted) return;
    context.showNotifier(
      l.ipingTunnelBatchCopySuccess(addresses.length),
      level: MessageLevel.success,
    );
  }

  Future<void> _batchExport(
    List<IpingTunnel> selected,
    IpingTunnelExportFormat format,
  ) async {
    final l = context.appLocalizations;
    final export = exportTunnels(selected, format);
    if (export.count == 0) {
      context.showNotifier(
        l.ipingTunnelBatchCopyEmpty,
        level: MessageLevel.warning,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: export.text));
    if (!mounted) return;
    context.showNotifier(
      l.ipingTunnelExportSuccess(export.count),
      level: MessageLevel.success,
    );
  }

  Widget _buildCard(IpingTunnel tunnel) => KeyedSubtree(
    key: ValueKey('tunnel-row-${tunnel.id}'),
    child: _TunnelCard(
      tunnel: tunnel,
      selectionMode: _selectionMode,
      isSelected: _selectedIds.contains(tunnel.id),
      onTap: () => _open(tunnel),
      onToggleSelect: () => _toggleSelection(tunnel.id),
      onSelect: () => _enterSelectionMode(tunnel.id),
      onCopy: _copy,
      onEdit: () => _openEdit(tunnel),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final data = _data;
    final failed = _error != null && data == null;
    final searching = _query.trim().isNotEmpty;
    final filtered =
        _filter != _TunnelFilter.all ||
        _tunnelType != null ||
        _autoRenew != null;
    final items = data?.items ?? const <IpingTunnel>[];
    final selected = [
      for (final tunnel in items)
        if (_selectedIds.contains(tunnel.id)) tunnel,
    ];
    return CommonScaffold(
      title: _selectionMode
          ? l.ipingTunnelBatchSelected(_selectedIds.length)
          : l.ipingTunnels,
      isLoading: _loading || _loadingMore,
      searchState: _selectionMode
          ? null
          : AppBarSearchState(
              onSearch: _search,
              query: searching ? _query : null,
            ),
      selectionActions: _selectionMode
          ? [
              IconButtonData(
                glyph: AppGlyphs.selectAll,
                tooltip: l.selectAll,
                onPressed: () => _toggleSelectAll(items),
              ),
              IconButtonData(
                glyph: AppGlyphs.close,
                tooltip: l.cancel,
                onPressed: _exitSelectionMode,
              ),
            ]
          : [
              IconButtonData(
                glyph: AppGlyphs.checkDouble,
                tooltip: l.ipingTunnelBatchOperations,
                onPressed: () => _enterSelectionMode(),
              ),
            ],
      primaryAction: _selectionMode
          ? null
          : IconButtonData(
              glyph: AppGlyphs.refresh,
              tooltip: l.retry,
              isLoading: _loading,
              onPressed: _loading ? null : () => _reload(),
            ),
      body: Builder(
        builder: (context) => AppBarClearance(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    if (data != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: _TunnelFilters(
                          filter: _filter,
                          tunnelType: _tunnelType,
                          autoRenew: _autoRenew,
                          ipType: _ipType,
                          listenPort: _listenPort,
                          resultCount: data.total,
                          onSelected: _select,
                          onTypeSelected: _selectType,
                          onAutoRenewSelected: _selectAutoRenew,
                          onIpTypeSelected: _selectIpType,
                          onListenPortSelected: _selectListenPort,
                          onOpenFilterSheet: _openFilterSheet,
                          onResetFilters: _resetFilters,
                        ),
                      ),
                    Expanded(
                      child: NullStatusSwitcher(
                        isLoading: _loading && data == null,
                        isEmpty: items.isEmpty,
                        isSearching: searching && !failed,
                        nullStatus: NullStatus(
                          illustration: failed
                              ? NullStatusIllustration.error
                              : filtered
                              ? NullStatusIllustration.search
                              : NullStatusIllustration.data,
                          label: failed
                              ? _failureText(
                                  l,
                                  _error!,
                                  fallback: l.ipingTunnelsLoadFailed,
                                )
                              : filtered
                              ? l.ipingTunnelsFilteredEmpty
                              : l.ipingTunnelsEmpty,
                          action: failed
                              ? TextButton(
                                  onPressed: () => _reload(),
                                  child: Text(l.retry),
                                )
                              : null,
                        ),
                        child: WidthBuilder(
                          builder: (context, width) {
                            final columns = width >= 640 ? 2 : 1;
                            final rowCount = (items.length / columns).ceil();
                            final hasLoadMore = data != null && data.hasMore;
                            return ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                (_selectionMode ? 96 : 24) +
                                    BottomInsetScope.of(context),
                              ),
                              itemCount: rowCount + (hasLoadMore ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: ipingCardGap),
                              itemBuilder: (context, rowIndex) {
                                if (rowIndex == rowCount) {
                                  return Center(
                                    child: TextButton(
                                      key: const ValueKey('tunnel-load-more'),
                                      onPressed: _loadingMore
                                          ? null
                                          : _loadMore,
                                      child: _loadingMore
                                          ? const CommonCircleLoading(size: 18)
                                          : Text(l.ipingTunnelLoadMore),
                                    ),
                                  );
                                }
                                if (columns == 1) {
                                  return _buildCard(items[rowIndex]);
                                }
                                final second = rowIndex * 2 + 1;
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    spacing: ipingCardGap,
                                    children: [
                                      Expanded(
                                        child: _buildCard(items[rowIndex * 2]),
                                      ),
                                      Expanded(
                                        child: second < items.length
                                            ? _buildCard(items[second])
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectionMode)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + BottomInsetScope.of(context),
                  child: _BatchActionBar(
                    selectedCount: _selectedIds.length,
                    onRenew: selected.isEmpty
                        ? null
                        : () => _openBatchRenew(selected),
                    onUpdate: selected.isEmpty
                        ? null
                        : () => _openBatchUpdate(selected),
                    onCopyAddresses: selected.isEmpty
                        ? null
                        : () => _batchCopyAddresses(selected),
                    onExport: selected.isEmpty
                        ? null
                        : (format) => _batchExport(selected, format),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TunnelFilters extends StatelessWidget {
  const _TunnelFilters({
    required this.filter,
    this.tunnelType,
    this.autoRenew,
    this.ipType,
    this.listenPort,
    required this.resultCount,
    required this.onSelected,
    required this.onTypeSelected,
    required this.onAutoRenewSelected,
    required this.onIpTypeSelected,
    required this.onListenPortSelected,
    required this.onOpenFilterSheet,
    required this.onResetFilters,
  });

  final _TunnelFilter filter;
  final String? tunnelType;
  final bool? autoRenew;
  final String? ipType;
  final int? listenPort;
  final int resultCount;
  final ValueChanged<_TunnelFilter> onSelected;
  final ValueChanged<String?> onTypeSelected;
  final ValueChanged<bool?> onAutoRenewSelected;
  final ValueChanged<String?> onIpTypeSelected;
  final ValueChanged<int?> onListenPortSelected;
  final VoidCallback onOpenFilterSheet;
  final VoidCallback onResetFilters;

  int get _activeCount =>
      (tunnelType != null ? 1 : 0) +
      (autoRenew != null ? 1 : 0) +
      (ipType != null ? 1 : 0) +
      (listenPort != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final activeCount = _activeCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 6,
                  children: [
                    for (final entry in <(_TunnelFilter, String, String)>[
                      (_TunnelFilter.all, 'all', l.ipingNativeIpAll),
                      (
                        _TunnelFilter.active,
                        'active',
                        l.ipingTunnelStatusActive,
                      ),
                      (
                        _TunnelFilter.inactive,
                        'inactive',
                        l.ipingTunnelStatusInactive,
                      ),
                      (_TunnelFilter.expired, 'expired', l.ipingTunnelExpired),
                    ])
                      IpingPill(
                        key: ValueKey('tunnel-filter-${entry.$2}'),
                        label: entry.$3,
                        selected: filter == entry.$1,
                        onPressed: () => onSelected(entry.$1),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IpingPill(
              key: const ValueKey('tunnel-filter-more'),
              glyph: AppGlyphs.filter,
              label: l.filter,
              trailing: activeCount == 0
                  ? null
                  : DecoratedBox(
                      decoration: ShapeDecoration(
                        color: scheme.primary,
                        shape: AppShape.full,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$activeCount',
                          style: AppTextStyle.caption2
                              .of(context, emphasized: true)
                              .toTabular
                              .copyWith(color: scheme.onPrimary),
                        ),
                      ),
                    ),
              onPressed: onOpenFilterSheet,
            ),
          ],
        ),
        if (activeCount > 0)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (tunnelType != null)
                IpingPill.removable(
                  label: tunnelTypeLabel(l, tunnelType!),
                  onPressed: () => onTypeSelected(null),
                ),
              if (autoRenew != null)
                IpingPill.removable(
                  label:
                      '${l.ipingTunnelAutoRenew}: '
                      '${_switchLabel(l, autoRenew, unset: '')}',
                  onPressed: () => onAutoRenewSelected(null),
                ),
              if (ipType != null)
                IpingPill.removable(
                  label: _ipTypeLabel(l, ipType),
                  onPressed: () => onIpTypeSelected(null),
                ),
              if (listenPort != null)
                IpingPill.removable(
                  label: '${l.ipingTunnelFilterPort}: $listenPort',
                  onPressed: () => onListenPortSelected(null),
                ),
              IpingPill(
                glyph: AppGlyphs.clearAll,
                label: l.reset,
                onPressed: onResetFilters,
              ),
            ],
          ),
        Text(
          l.ipingTunnelsResultCount(resultCount),
          style: context.listCaptionStyle,
        ),
      ],
    );
  }
}

class _TunnelFilterSheet extends StatefulWidget {
  const _TunnelFilterSheet({
    required this.filter,
    required this.tunnelType,
    required this.autoRenew,
    required this.ipType,
    required this.listenPort,
    required this.onApply,
  });

  final _TunnelFilter filter;
  final String? tunnelType;
  final bool? autoRenew;
  final String? ipType;
  final int? listenPort;
  final void Function(
    _TunnelFilter filter,
    String? tunnelType,
    bool? autoRenew,
    String? ipType,
    int? listenPort,
  )
  onApply;

  @override
  State<_TunnelFilterSheet> createState() => _TunnelFilterSheetState();
}

class _TunnelFilterSheetState extends State<_TunnelFilterSheet> {
  late _TunnelFilter _filter;
  late String? _tunnelType;
  late bool? _autoRenew;
  late String? _ipType;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
    _tunnelType = widget.tunnelType;
    _autoRenew = widget.autoRenew;
    _ipType = widget.ipType;
    _portController = TextEditingController(
      text: widget.listenPort?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _filter = _TunnelFilter.all;
      _tunnelType = null;
      _autoRenew = null;
      _ipType = null;
      _portController.clear();
    });
  }

  void _apply() {
    final port = int.tryParse(_portController.text.trim());
    widget.onApply(_filter, _tunnelType, _autoRenew, _ipType, port);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return CommonScaffold(
      title: l.ipingTunnelFilterTitle,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.clearAll,
          tooltip: l.reset,
          onPressed: _reset,
        ),
      ],
      primaryAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: l.confirm,
        onPressed: _apply,
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            generateSection(
              items: [
                ListItem<_TunnelFilter>.options(
                  key: const ValueKey('filter-sheet-status'),
                  title: Text(l.status),
                  options: _TunnelFilter.values,
                  value: _filter,
                  textBuilder: (filter) => _filterLabel(l, filter),
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                ListItem<String?>.options(
                  key: const ValueKey('filter-sheet-type'),
                  title: Text(l.ipingTunnelFilterType),
                  options: const [null, ..._tunnelTypes],
                  value: _tunnelType,
                  textBuilder: (type) => type == null
                      ? l.ipingTunnelFilterAll
                      : tunnelTypeLabel(l, type),
                  onChanged: (type) => setState(() => _tunnelType = type),
                ),
                ListItem<String?>.options(
                  key: const ValueKey('filter-sheet-ip-type'),
                  title: Text(l.ipingTunnelFilterIpType),
                  options: const [null, 'v4', 'v6'],
                  value: _ipType,
                  textBuilder: (ipType) => _ipTypeLabel(l, ipType),
                  onChanged: (ipType) => setState(() => _ipType = ipType),
                ),
                ListItem<bool?>.options(
                  key: const ValueKey('filter-sheet-auto-renew'),
                  title: Text(l.ipingTunnelFilterAutoRenew),
                  options: const [null, true, false],
                  value: _autoRenew,
                  textBuilder: (value) =>
                      _switchLabel(l, value, unset: l.ipingTunnelFilterAll),
                  onChanged: (value) => setState(() => _autoRenew = value),
                ),
                FormRow(
                  title: l.ipingTunnelFilterPort,
                  trailing: FormRowTextField(
                    key: const ValueKey('filter-sheet-port-input'),
                    controller: _portController,
                    hintText: l.ipingTunnelFilterPortHint,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onFieldSubmitted: (_) => _apply(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TunnelCard extends StatelessWidget {
  const _TunnelCard({
    required this.tunnel,
    required this.onTap,
    required this.onCopy,
    required this.onEdit,
    required this.onSelect,
    required this.onToggleSelect,
    this.selectionMode = false,
    this.isSelected = false,
  });

  final IpingTunnel tunnel;
  final VoidCallback onTap;
  final ValueChanged<String> onCopy;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onToggleSelect;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final addresses = tunnel.listenAddresses;
    return ContextMenuRegion(
      menuItems: selectionMode
          ? null
          : [
              CommonPopupMenuItem(
                label: l.ipingTunnelEdit,
                glyph: AppGlyphs.edit,
                onPressed: onEdit,
              ),
              if (addresses.isNotEmpty)
                CommonPopupMenuItem(
                  label: l.ipingTunnelCopyListen,
                  glyph: AppGlyphs.copy,
                  onPressed: () => onCopy(addresses.first),
                ),
              CommonPopupMenuItem(
                label: l.ipingTunnelBatchOperations,
                glyph: AppGlyphs.checkDouble,
                onPressed: onSelect,
              ),
            ],
      child: CommonCard(
        isSelected: isSelected,
        radius: ipingCardCorner,
        padding: ipingCardPadding,
        onPressed: selectionMode ? onToggleSelect : onTap,
        child: _TunnelCardBody(
          tunnel: tunnel,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onToggleSelect: onToggleSelect,
          onCopy: onCopy,
        ),
      ),
    );
  }
}

class _TunnelCardBody extends StatelessWidget {
  const _TunnelCardBody({
    required this.tunnel,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onCopy,
  });

  final IpingTunnel tunnel;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: scheme.onSurfaceVariant);
    final addresses = tunnel.listenAddresses;
    final listen = addresses.isEmpty
        ? l.ipingTunnelListenWaiting
        : addresses.length == 1
        ? addresses.first
        : l.ipingTunnelMoreAddresses(addresses.first, addresses.length - 1);
    final expiryColor = tunnel.isExpired
        ? scheme.warning
        : scheme.onSurfaceVariant;
    final meta = AppTextStyle.caption1.of(context).toTabular;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (selectionMode)
              SizedBox.square(
                dimension: ipingMarkSize,
                child: CommonCheckBox(
                  value: isSelected,
                  isCircle: true,
                  onChanged: (_) => onToggleSelect(),
                ),
              )
            else
              const IpingCardMark(child: _tunnelGlyph),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    tunnel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.headline
                        .of(context)
                        .copyWith(color: scheme.onSurface),
                  ),
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(
                        child: Text(
                          tunnelTypeLabel(l, tunnel.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: secondary,
                        ),
                      ),
                      if (tunnel.autoRenew)
                        Tooltip(
                          message: l.ipingTunnelAutoRenew,
                          child: GlyphIcon(
                            AppGlyphs.sync,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TunnelStatusChip(tunnel: tunnel),
          ],
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: context.raisedSurfaceLevel.colorOf(scheme),
            shape: AppShape.md,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 2, 0),
              child: Row(
                spacing: 8,
                children: [
                  GlyphIcon(
                    AppGlyphs.link,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      listen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.callout
                          .of(context)
                          .toTabular
                          .copyWith(
                            color: addresses.isEmpty
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                    ),
                  ),
                  if (addresses.isNotEmpty)
                    IconButton(
                      tooltip: l.copy,
                      visualDensity: VisualDensity.compact,
                      onPressed: selectionMode
                          ? null
                          : () => onCopy(addresses.first),
                      icon: const GlyphIcon(AppGlyphs.copy, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (tunnel.portInUse) ...[
          const SizedBox(height: 10),
          const _PortConflictNote(),
        ],
        if (tunnel.entrance != null ||
            tunnel.exit != null ||
            tunnel.poolExit) ...[
          const SizedBox(height: 12),
          _RouteLine(tunnel: tunnel),
        ],
        const SizedBox(height: 14),
        _TrafficBar(tunnel: tunnel),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l.ipingTunnelTrafficOf(
                  ipingGigabytes(tunnel.traffic),
                  ipingGigabytes(tunnel.totalTraffic),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            GlyphIcon(AppGlyphs.clock, size: 12, color: expiryColor),
            const SizedBox(width: 4),
            Text(
              tunnel.expiredAt?.show ?? '—',
              style: meta.copyWith(color: expiryColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.tunnel});

  final IpingTunnel tunnel;

  Widget _end(BuildContext context, IpingTunnelEndpoint? endpoint) {
    final scheme = context.colorScheme;
    final style = AppTextStyle.footnote.of(context);
    final secondary = style.copyWith(color: scheme.onSurfaceVariant);
    if (endpoint == null) {
      return Text(
        tunnel.poolExit ? context.appLocalizations.ipingTunnelPoolExit : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: secondary,
      );
    }
    return Text.rich(
      TextSpan(
        text: endpoint.name,
        style: style.copyWith(color: scheme.onSurface),
        children: [
          TextSpan(
            text: ' ×${tunnelRateLabel(endpoint.trafficRate)}',
            style: secondary.toTabular,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: _end(context, tunnel.entrance)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GlyphIcon(
            AppGlyphs.chevronForward,
            size: 12,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(child: _end(context, tunnel.exit)),
      ],
    );
  }
}

class _PortConflictNote extends StatelessWidget {
  const _PortConflictNote();

  @override
  Widget build(BuildContext context) {
    final warning = context.colorScheme.warning;
    return Row(
      spacing: 6,
      children: [
        GlyphIcon(AppGlyphs.warning, size: 15, color: warning),
        Flexible(
          child: Text(
            context.appLocalizations.ipingTunnelPortConflict,
            style: AppTextStyle.footnote
                .of(context, emphasized: true)
                .copyWith(color: warning),
          ),
        ),
      ],
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({required this.tunnel, this.height = 4});

  final IpingTunnel tunnel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final progress = tunnel.totalTraffic > 0
        ? (tunnel.traffic / tunnel.totalTraffic).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return ClipRSuperellipse(
      borderRadius: AppRadius.full,
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        backgroundColor: context.raisedSurfaceLevel.colorOf(scheme),
        valueColor: AlwaysStoppedAnimation(
          progress > 0.9 ? scheme.warning : scheme.primary,
        ),
      ),
    );
  }
}

class _TunnelStatusChip extends StatelessWidget {
  const _TunnelStatusChip({required this.tunnel});

  final IpingTunnel tunnel;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final (label, color, foreground) = tunnel.isExpired
        ? (
            l.ipingTunnelExpired,
            scheme.warningContainer,
            scheme.onWarningContainer,
          )
        : tunnel.enabled
        ? (
            l.ipingTunnelStatusActive,
            scheme.successContainer,
            scheme.onSuccessContainer,
          )
        : (
            l.ipingTunnelStatusInactive,
            context.raisedSurfaceLevel.colorOf(scheme),
            scheme.onSurfaceVariant,
          );
    return TonalChip(label: label, color: color, foregroundColor: foreground);
  }
}

class IpingTunnelDetailPage extends ConsumerStatefulWidget {
  const IpingTunnelDetailPage({
    super.key,
    required this.tunnel,
    this.onChanged,
  });

  final IpingTunnel tunnel;
  final ValueChanged<IpingTunnel>? onChanged;

  @override
  ConsumerState<IpingTunnelDetailPage> createState() =>
      _IpingTunnelDetailPageState();
}

class _IpingTunnelDetailPageState extends ConsumerState<IpingTunnelDetailPage> {
  late IpingTunnel _tunnel = widget.tunnel;
  var _busy = false;
  var _probing = false;
  var _latency = <String, int>{};

  Future<void> _probe(List<String> addresses) async {
    if (_probing) return;
    setState(() {
      _probing = true;
      _latency = {};
    });
    final results = await Future.wait(addresses.map(probeListenAddress));
    if (!mounted) return;
    setState(() {
      _probing = false;
      _latency = Map.fromIterables(addresses, results);
    });
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }

  Future<void> _apply({
    String? status,
    bool? autoRenew,
    bool renew = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.appLocalizations;
    try {
      final api = ref.read(ipingAuthenticatedApiProvider);
      if (renew) {
        await api.renewTunnel(_tunnel.id);
      } else {
        await api.updateTunnel(
          _tunnel.id,
          status: status,
          autoRenew: autoRenew,
        );
      }
      IpingTunnel? fetched;
      try {
        fetched = await api.tunnel(_tunnel.id);
      } catch (_) {
        fetched = null;
      }
      if (!mounted) return;
      final next =
          fetched ?? _tunnel.copyWith(status: status, autoRenew: autoRenew);
      setState(() => _tunnel = next);
      widget.onChanged?.call(next);
      context.showNotifier(
        renew ? l.ipingTunnelRenewed : l.ipingTunnelUpdated,
        level: MessageLevel.success,
      );
    } on IpingException catch (error) {
      if (!mounted) return;
      context.showNotifier(
        _failureText(
          l,
          error,
          fallback: renew
              ? l.ipingTunnelRenewFailed
              : l.ipingTunnelUpdateFailed,
        ),
        level: MessageLevel.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _renew() async {
    final l = context.appLocalizations;
    final price = _tunnel.planPrice;
    final confirmed = await confirmChange(
      context,
      message: price == null
          ? l.ipingTunnelRenewConfirm
          : l.ipingTunnelRenewConfirmPrice(ipingCurrency(price.toDouble())),
      confirmText: l.ipingTunnelRenew,
      destructive: false,
    );
    if (confirmed == true && mounted) await _apply(renew: true);
  }

  Future<void> _openEdit() async {
    await showInSheet<void>(
      context,
      builder: (_) => IpingTunnelEditPage(
        tunnel: _tunnel,
        onChanged: (next) {
          setState(() => _tunnel = next);
          widget.onChanged?.call(next);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final tunnel = _tunnel;
    final addresses = tunnel.listenAddresses;
    final entrance = tunnel.entrance;
    final exit = tunnel.exit;
    final tabular = context.listTitleStyle.toTabular;
    return CommonScaffold(
      title: tunnel.name,
      isLoading: _busy,
      primaryAction: IconButtonData(
        glyph: AppGlyphs.edit,
        tooltip: l.ipingTunnelEdit,
        onPressed: _busy ? null : _openEdit,
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            _TunnelOverview(tunnel: tunnel, onRenew: _busy ? null : _renew),
            generateSection(
              title: l.ipingTunnelListen,
              actions: [
                if (tunnel.listenPort != null && addresses.isNotEmpty)
                  IconButtonData(
                    glyph: AppGlyphs.speed,
                    tooltip: l.ipingTunnelTestConnection,
                    isLoading: _probing,
                    onPressed: _probing ? null : () => _probe(addresses),
                  ),
              ],
              items: addresses.isEmpty
                  ? [ListItem(title: Text(l.ipingTunnelListenWaiting))]
                  : [
                      for (final address in addresses)
                        ListItem(
                          title: Text(address, style: tabular),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 10,
                            children: [
                              if (_latency[address] case final ms?)
                                Text(
                                  ms < 0 ? l.timeout : '$ms ms',
                                  style: AppTextStyle.footnote
                                      .of(context, emphasized: true)
                                      .toTabular
                                      .copyWith(
                                        color: context.colorScheme.delayColor(
                                          ms,
                                        ),
                                      ),
                                ),
                              const GlyphIcon(AppGlyphs.copy),
                            ],
                          ),
                          onTap: _busy ? null : () => _copy(address),
                        ),
                    ],
            ),
            if (entrance != null || exit != null || tunnel.poolExit) ...[
              _sectionGap,
              generateSection(
                items: [
                  if (entrance != null)
                    _EndpointRow(
                      title: l.ipingTunnelEntrance,
                      endpoint: entrance,
                    ),
                  if (exit != null)
                    _EndpointRow(title: l.ipingTunnelExit, endpoint: exit)
                  else if (tunnel.poolExit)
                    ListItem(
                      title: Text(l.ipingTunnelExit),
                      subtitle: Text(l.ipingTunnelPoolExit),
                    ),
                ],
              ),
            ],
            if (tunnel.forwardAddresses.isNotEmpty)
              generateSection(
                title: l.ipingTunnelForward,
                items: [
                  for (final entry in tunnel.forwardAddresses.entries)
                    ListItem(
                      title: Text(entry.key, style: tabular),
                      trailing: entry.value == 1
                          ? null
                          : MetaChip(label: '${entry.value}'),
                    ),
                ],
              ),
            _sectionGap,
            generateSection(
              items: [
                KeyedSubtree(
                  key: const ValueKey('tunnel-enabled'),
                  child: ListItem.toggle(
                    title: Text(l.ipingTunnelStatusActive),
                    value: tunnel.enabled,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              _apply(status: value ? 'active' : 'inactive'),
                  ),
                ),
                KeyedSubtree(
                  key: const ValueKey('tunnel-auto-renew'),
                  child: ListItem.toggle(
                    title: Text(l.ipingTunnelAutoRenew),
                    value: tunnel.autoRenew,
                    onChanged: _busy
                        ? null
                        : (value) => _apply(autoRenew: value),
                  ),
                ),
              ],
              footer: l.ipingTunnelAutoRenewDesc,
            ),
          ],
        ),
      ),
    );
  }
}

class _TunnelOverview extends StatelessWidget {
  const _TunnelOverview({required this.tunnel, required this.onRenew});

  final IpingTunnel tunnel;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final level = context.raisedSurfaceLevel;
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: scheme.onSurfaceVariant);
    final plan = tunnel.planName;
    final price = tunnel.planPrice;
    final planLine = plan == null
        ? null
        : price == null
        ? plan
        : '$plan · ${ipingCurrency(price.toDouble())}';
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: level.colorOf(scheme),
        shape: AppShape.xl,
      ),
      child: SurfaceScope(
        level: level,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IpingCardMark(child: _tunnelGlyph),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          tunnelTypeLabel(l, tunnel.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.headline
                              .of(context)
                              .copyWith(color: scheme.onSurface),
                        ),
                        if (planLine != null)
                          Text(
                            planLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: secondary,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TunnelStatusChip(tunnel: tunnel),
                ],
              ),
              if (tunnel.portInUse) ...[
                const SizedBox(height: 14),
                const _PortConflictNote(),
              ],
              const SizedBox(height: 22),
              Text(l.ipingTunnelTraffic, style: secondary),
              const SizedBox(height: 2),
              Text(
                l.ipingTunnelTrafficOf(
                  ipingGigabytes(tunnel.traffic),
                  ipingGigabytes(tunnel.totalTraffic),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.title3
                    .of(context, emphasized: true)
                    .toTabular
                    .copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 10),
              _TrafficBar(tunnel: tunnel, height: 6),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(l.ipingTunnelExpires, style: secondary),
                        Text(
                          tunnel.expiredAt?.show ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.headline
                              .of(context)
                              .toTabular
                              .copyWith(
                                color: tunnel.isExpired
                                    ? scheme.warning
                                    : scheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const ValueKey('tunnel-renew'),
                    onPressed: onRenew,
                    icon: const GlyphIcon(AppGlyphs.refresh, fill: 1),
                    label: Text(l.ipingTunnelRenew),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.title, required this.endpoint});

  final String title;
  final IpingTunnelEndpoint endpoint;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(title),
      subtitle: Text(endpoint.name),
      trailing: MetaChip(
        label: context.appLocalizations.ipingTunnelRate(
          tunnelRateLabel(endpoint.trafficRate),
        ),
      ),
    );
  }
}

enum _EditField { name, address, port }

class IpingTunnelEditPage extends ConsumerStatefulWidget {
  const IpingTunnelEditPage({super.key, required this.tunnel, this.onChanged});

  final IpingTunnel tunnel;
  final ValueChanged<IpingTunnel>? onChanged;

  @override
  ConsumerState<IpingTunnelEditPage> createState() =>
      _IpingTunnelEditPageState();
}

class _IpingTunnelEditPageState extends ConsumerState<IpingTunnelEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _poolCountryController;
  late final TextEditingController _poolIntervalController;
  late bool _enabled;
  late bool _autoRenew;
  late int? _listenPort;
  var _busy = false;
  _EditField? _invalid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tunnel.name);
    var host = '';
    var port = '';
    if (widget.tunnel.forwardAddresses.isNotEmpty) {
      final first = widget.tunnel.forwardAddresses.keys.first;
      final lastColon = first.lastIndexOf(':');
      if (lastColon > 0) {
        host = first.substring(0, lastColon);
        port = first.substring(lastColon + 1);
      } else {
        host = first;
      }
    }
    _hostController = TextEditingController(text: host);
    _portController = TextEditingController(text: port);
    _usernameController = TextEditingController(
      text: widget.tunnel.forwardUsername ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.tunnel.forwardPassword ?? '',
    );
    _poolCountryController = TextEditingController(
      text: widget.tunnel.poolCountry ?? '',
    );
    _poolIntervalController = TextEditingController(
      text: widget.tunnel.poolIntervalMinutes?.toString() ?? '0',
    );
    _enabled = widget.tunnel.enabled;
    _autoRenew = widget.tunnel.autoRenew;
    _listenPort = widget.tunnel.listenPort;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _poolCountryController.dispose();
    _poolIntervalController.dispose();
    super.dispose();
  }

  void _changed([String? _]) {
    if (_error == null && _invalid == null) return;
    setState(() {
      _error = null;
      _invalid = null;
    });
  }

  void _refuse(_EditField? field, String message) {
    setState(() {
      _invalid = field;
      _error = message;
    });
  }

  Future<void> _switchPort() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.appLocalizations;
    try {
      final port = await ref
          .read(ipingAuthenticatedApiProvider)
          .switchPort(widget.tunnel.id);
      if (!mounted) return;
      setState(() => _listenPort = port);
      final next = widget.tunnel.copyWith(listenPort: port);
      widget.onChanged?.call(next);
      context.showNotifier(
        l.ipingTunnelSwitchPortSuccess,
        level: MessageLevel.success,
      );
    } catch (error) {
      if (!mounted) return;
      context.showNotifier(
        _failureText(l, error, fallback: l.ipingTunnelSwitchPortFailed),
        level: MessageLevel.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchIp() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.appLocalizations;
    try {
      await ref.read(ipingAuthenticatedApiProvider).switchIp(widget.tunnel.id);
      if (!mounted) return;
      context.showNotifier(
        l.ipingTunnelSwitchIpSuccess,
        level: MessageLevel.success,
      );
    } catch (error) {
      if (!mounted) return;
      context.showNotifier(
        _failureText(l, error, fallback: l.ipingTunnelSwitchIpFailed),
        level: MessageLevel.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final l = context.appLocalizations;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = parseProxyAddresses(data?.text?.trim() ?? '');
    if (!mounted) return;
    if (parsed.isEmpty) {
      context.showNotifier(
        l.ipingTunnelImportClipboardFailed,
        level: MessageLevel.error,
      );
      return;
    }
    final first = parsed.first;
    setState(() {
      _hostController.text = first.host;
      _portController.text = first.port.toString();
      if (first.username.isNotEmpty || first.password.isNotEmpty) {
        _usernameController.text = first.username;
        _passwordController.text = first.password;
      }
      _error = null;
      _invalid = null;
    });
    context.showNotifier(
      l.ipingTunnelImportClipboardSuccess,
      level: MessageLevel.success,
    );
  }

  Future<void> _pickNativeIp() async {
    final proxy = await showInSheet<IpingUserProxy>(
      context,
      builder: (_) => const _UserProxyPickerSheet(),
    );
    if (proxy == null || !mounted) return;
    setState(() {
      _hostController.text = proxy.host;
      _portController.text = proxy.port.toString();
      _usernameController.text = proxy.username;
      _passwordController.text = proxy.password;
      _error = null;
      _invalid = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = context.appLocalizations;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _refuse(_EditField.name, l.ipingTunnelNameHint);
      return;
    }

    Map<String, num>? forwardAddresses;
    String? forwardUsername;
    String? forwardPassword;
    if (!widget.tunnel.poolExit) {
      final host = _hostController.text.trim();
      final portStr = _portController.text.trim();
      if (host.isEmpty || portStr.isEmpty) {
        _refuse(_EditField.address, l.ipingTunnelForwardAddressRequired);
        return;
      }
      final port = int.tryParse(portStr);
      if (port == null || port < 1 || port > 65535) {
        _refuse(_EditField.port, l.ipingTunnelPortInvalid);
        return;
      }
      forwardAddresses = {'$host:$port': 1};
      forwardUsername = _usernameController.text.trim();
      forwardPassword = _passwordController.text.trim();
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _invalid = null;
    });
    try {
      final api = ref.read(ipingAuthenticatedApiProvider);
      if (widget.tunnel.poolExit) {
        final country = _poolCountryController.text.trim();
        final interval = int.tryParse(_poolIntervalController.text.trim()) ?? 0;
        await api.updatePoolSettings(
          widget.tunnel.id,
          name: name,
          country: country.isNotEmpty ? country : null,
          intervalMinutes: interval,
        );
        await api.updateTunnel(
          widget.tunnel.id,
          status: _enabled ? 'active' : 'inactive',
          autoRenew: _autoRenew,
        );
      } else {
        await api.saveTunnel(
          id: widget.tunnel.id,
          name: name,
          forwardAddresses: forwardAddresses,
          forwardUsername: forwardUsername,
          forwardPassword: forwardPassword,
          status: _enabled ? 'active' : 'inactive',
          autoRenew: _autoRenew,
        );
      }
      IpingTunnel? fetched;
      try {
        fetched = await api.tunnel(widget.tunnel.id);
      } catch (_) {
        fetched = null;
      }
      if (!mounted) return;
      final next =
          fetched ??
          widget.tunnel.copyWith(
            name: name,
            status: _enabled ? 'active' : 'inactive',
            autoRenew: _autoRenew,
            listenPort: _listenPort,
            forwardAddresses:
                forwardAddresses ?? widget.tunnel.forwardAddresses,
            forwardUsername: forwardUsername ?? widget.tunnel.forwardUsername,
            forwardPassword: forwardPassword ?? widget.tunnel.forwardPassword,
          );
      widget.onChanged?.call(next);
      Navigator.of(context).pop();
      context.showNotifier(l.ipingTunnelUpdated, level: MessageLevel.success);
    } catch (error) {
      if (!mounted) return;
      _refuse(
        null,
        _failureText(l, error, fallback: l.ipingTunnelUpdateFailed),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _readOnly(String value, {bool secret = false}) => Text(
    value.isEmpty
        ? '—'
        : secret
        ? '•' * 8
        : value,
    style: context.listTitleStyle.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    ),
  );

  List<Widget> _poolRows(AppLocalizations l) => [
    FormRow(
      title: l.ipingTunnelPoolCountry,
      trailing: FormRowTextField(
        controller: _poolCountryController,
        hintText: 'US / HK',
        autocorrect: false,
        textInputAction: TextInputAction.next,
        onChanged: _changed,
      ),
    ),
    FormRow(
      title: l.ipingTunnelPoolInterval,
      trailing: FormRowTextField(
        controller: _poolIntervalController,
        hintText: '0',
        keyboardType: TextInputType.number,
        autocorrect: false,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: _changed,
      ),
    ),
    KeyedSubtree(
      key: const ValueKey('tunnel-edit-switch-ip'),
      child: ListItem(
        title: Text(l.ipingTunnelSwitchIp),
        trailing: const GlyphIcon(AppGlyphs.shuffle),
        onTap: _busy ? null : _switchIp,
      ),
    ),
  ];

  List<Widget> _forwardRows(AppLocalizations l) {
    if (!widget.tunnel.canChangeForwardAddress) {
      return [
        FormRow(
          title: l.ipingTunnelForwardHost,
          trailing: _readOnly(_hostController.text),
        ),
        FormRow(
          title: l.ipingTunnelForwardPort,
          trailing: _readOnly(_portController.text),
        ),
        FormRow(
          title: l.ipingTunnelUsername,
          trailing: _readOnly(_usernameController.text),
        ),
        FormRow(
          title: l.ipingTunnelPassword,
          trailing: _readOnly(_passwordController.text, secret: true),
        ),
      ];
    }
    return [
      FormRow(
        title: l.ipingTunnelForwardHost,
        invalid: _invalid == _EditField.address,
        trailing: FormRowTextField(
          controller: _hostController,
          hintText: '1.2.3.4 / example.com',
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onChanged: _changed,
        ),
      ),
      FormRow(
        title: l.ipingTunnelForwardPort,
        invalid: _invalid == _EditField.address || _invalid == _EditField.port,
        trailing: FormRowTextField(
          controller: _portController,
          hintText: '1080',
          keyboardType: TextInputType.number,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _changed,
        ),
      ),
      FormRow(
        title: l.ipingTunnelUsername,
        trailing: FormRowTextField(
          controller: _usernameController,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onChanged: _changed,
        ),
      ),
      FormRow(
        title: l.ipingTunnelPassword,
        trailing: FormRowSecretTextField(
          controller: _passwordController,
          textInputAction: TextInputAction.done,
          onChanged: _changed,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final tunnel = widget.tunnel;
    final canEditAddress = tunnel.canChangeForwardAddress && !_busy;
    return FormPage(
      title: l.ipingTunnelEdit,
      saving: _busy,
      error: _error,
      onSave: _save,
      children: [
        AbsorbPointer(
          absorbing: _busy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              generateSection(
                items: [
                  FormRow(
                    title: l.ipingTunnelName,
                    invalid: _invalid == _EditField.name,
                    trailing: FormRowTextField(
                      controller: _nameController,
                      hintText: l.ipingTunnelNameHint,
                      textInputAction: TextInputAction.next,
                      onChanged: _changed,
                    ),
                  ),
                ],
              ),
              if (tunnel.poolExit)
                generateSection(
                  title: l.ipingTunnelExit,
                  items: _poolRows(l),
                  footer:
                      '${l.ipingTunnelPoolExit} '
                      '${l.ipingTunnelPoolIntervalHint}',
                )
              else
                generateSection(
                  title: l.ipingTunnelForward,
                  actions: [
                    IconButtonData(
                      glyph: AppGlyphs.paste,
                      tooltip: l.ipingTunnelImportClipboard,
                      onPressed: canEditAddress ? _importFromClipboard : null,
                    ),
                    IconButtonData(
                      glyph: AppGlyphs.proxies,
                      tooltip: l.ipingTunnelSelectFromNativeIps,
                      onPressed: canEditAddress ? _pickNativeIp : null,
                    ),
                  ],
                  items: _forwardRows(l),
                  footer: tunnel.canChangeForwardAddress
                      ? null
                      : l.ipingTunnelForwardLocked,
                ),
              _sectionGap,
              generateSection(
                items: [
                  ListItem.toggle(
                    title: Text(l.ipingTunnelStatusActive),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  ListItem.toggle(
                    title: Text(l.ipingTunnelAutoRenew),
                    value: _autoRenew,
                    onChanged: (value) => setState(() => _autoRenew = value),
                  ),
                ],
                footer: l.ipingTunnelAutoRenewDesc,
              ),
              if (!tunnel.poolExit && _listenPort != null) ...[
                _sectionGap,
                generateSection(
                  items: [
                    FormRow(
                      title: l.ipingTunnelFilterPort,
                      trailing: Text(
                        '$_listenPort',
                        style: context.listTitleStyle.toTabular.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ListItem(
                      title: Text(l.ipingTunnelSwitchPort),
                      trailing: const GlyphIcon(AppGlyphs.refresh),
                      onTap: _switchPort,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UserProxyPickerSheet extends ConsumerStatefulWidget {
  const _UserProxyPickerSheet();

  @override
  ConsumerState<_UserProxyPickerSheet> createState() =>
      _UserProxyPickerSheetState();
}

class _UserProxyPickerSheetState extends ConsumerState<_UserProxyPickerSheet> {
  var _loading = true;
  String? _error;
  List<IpingUserProxy> _proxies = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(ipingAuthenticatedApiProvider).userProxies();
      if (!mounted) return;
      setState(() {
        _proxies = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final failed = _error != null;
    return CommonScaffold(
      title: l.ipingTunnelSelectFromNativeIps,
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: _loading,
          isEmpty: failed || _proxies.isEmpty,
          nullStatus: NullStatus(
            illustration: failed
                ? NullStatusIllustration.error
                : NullStatusIllustration.data,
            label: failed
                ? l.ipingTunnelsLoadFailed
                : l.ipingTunnelSelectFromNativeIpsEmpty,
            action: failed
                ? TextButton(onPressed: _fetch, child: Text(l.retry))
                : null,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              context.contentTopPadding,
              16,
              24 + BottomInsetScope.of(context),
            ),
            children: [
              generateSection(
                items: [
                  for (final proxy in _proxies)
                    ListItem(
                      title: Text(
                        '${proxy.host}:${proxy.port}',
                        style: context.listTitleStyle.toTabular,
                      ),
                      subtitle: switch (_proxyDetails(proxy)) {
                        final details? => Text(details),
                        null => null,
                      },
                      trailing: MetaChip(label: proxy.type.toUpperCase()),
                      onTap: () => Navigator.of(context).pop(proxy),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _proxyDetails(IpingUserProxy proxy) {
  final details = [
    for (final value in [proxy.country, proxy.city, proxy.remarks])
      if (value != null && value.isNotEmpty) value,
  ];
  return details.isEmpty ? null : details.join(' · ');
}

class _BatchActionBar extends StatelessWidget {
  const _BatchActionBar({
    required this.selectedCount,
    required this.onRenew,
    required this.onUpdate,
    required this.onCopyAddresses,
    required this.onExport,
  });

  static const _compactWidth = 440.0;

  final int selectedCount;
  final VoidCallback? onRenew;
  final VoidCallback? onUpdate;
  final VoidCallback? onCopyAddresses;
  final ValueChanged<IpingTunnelExportFormat>? onExport;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final level = SurfaceLevel.floatingOf(scheme);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: AppShape.full,
        shadows: dockShadows(scheme),
      ),
      child: Material(
        color: level.colorOf(scheme),
        shape: AppShape.full,
        clipBehavior: Clip.antiAlias,
        child: SurfaceScope(
          level: level,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < _compactWidth;
                return Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Text(
                        l.ipingTunnelBatchSelected(selectedCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.subheadline
                            .of(context, emphasized: true)
                            .toTabular
                            .copyWith(color: scheme.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: l.ipingTunnelBatchCopyAddresses,
                      onPressed: onCopyAddresses,
                      icon: const GlyphIcon(AppGlyphs.copy),
                    ),
                    CommonPopupBox(
                      targetBuilder: (open) => IconButton(
                        tooltip: l.ipingTunnelExport,
                        onPressed: onExport == null ? null : open,
                        icon: const GlyphIcon(AppGlyphs.export),
                      ),
                      popupBuilder: (_) => CommonPopupMenu(
                        items: [
                          for (final (format, label) in [
                            (
                              IpingTunnelExportFormat.lines,
                              l.ipingTunnelExportLines,
                            ),
                            (
                              IpingTunnelExportFormat.clash,
                              l.ipingTunnelExportClash,
                            ),
                            (
                              IpingTunnelExportFormat.csv,
                              l.ipingTunnelExportCsv,
                            ),
                          ])
                            CommonPopupMenuItem(
                              label: label,
                              onPressed: () => onExport?.call(format),
                            ),
                        ],
                      ),
                    ),
                    if (compact) ...[
                      IconButton.filledTonal(
                        tooltip: l.ipingTunnelBatchUpdate,
                        onPressed: onUpdate,
                        icon: const GlyphIcon(AppGlyphs.sliders, fill: 1),
                      ),
                      IconButton.filled(
                        tooltip: l.ipingTunnelBatchRenew,
                        onPressed: onRenew,
                        icon: const GlyphIcon(AppGlyphs.refresh, fill: 1),
                      ),
                    ] else ...[
                      FilledButton.tonalIcon(
                        onPressed: onUpdate,
                        icon: const GlyphIcon(AppGlyphs.sliders, fill: 1),
                        label: Text(l.ipingTunnelBatchUpdate),
                      ),
                      FilledButton.icon(
                        onPressed: onRenew,
                        icon: const GlyphIcon(AppGlyphs.refresh, fill: 1),
                        label: Text(l.ipingTunnelBatchRenew),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchRenewSheet extends ConsumerStatefulWidget {
  const _BatchRenewSheet({required this.tunnels});

  final List<IpingTunnel> tunnels;

  @override
  ConsumerState<_BatchRenewSheet> createState() => _BatchRenewSheetState();
}

class _BatchRenewSheetState extends ConsumerState<_BatchRenewSheet> {
  var _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final balance = ref.watch(ipingUserInfoProvider).asData?.value?.balance;
    final items = widget.tunnels;
    final total = items.fold<double>(
      0.0,
      (sum, t) => sum + (t.planPrice?.toDouble() ?? 0.0),
    );
    final isBlocked =
        items.isEmpty ||
        items.any((t) => t.type == 'trial' || t.planPrice == null);
    final isInsufficient = balance != null && balance < total;
    final value = context.listTitleStyle.toTabular;

    return CommonScaffold(
      title: l.ipingTunnelBatchRenew,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: l.confirm,
        isLoading: _submitting,
        onPressed: (isBlocked || isInsufficient || _submitting)
            ? null
            : () => _submit(items.map((t) => t.id).toList()),
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            ErrorBanner(
              message:
                  _error ??
                  (isInsufficient ? l.ipingTunnelBatchRenewInsufficient : null),
            ),
            generateSection(
              title: l.ipingTunnelBatchRenewConfirm,
              items: [
                FormRow(
                  title: l.ipingTunnelBatchRenewBalance,
                  trailing: Text(
                    balance == null ? '—' : ipingCurrency(balance),
                    style: value.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                FormRow(
                  title: l.ipingTunnelBatchRenewTotal,
                  invalid: isInsufficient,
                  trailing: Text(
                    isBlocked ? '—' : ipingCurrency(total),
                    style: AppTextStyle.headline
                        .of(context, emphasized: true)
                        .toTabular
                        .copyWith(
                          color: isInsufficient
                              ? scheme.error
                              : scheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            generateSection(
              title: l.ipingTunnelsResultCount(items.length),
              items: [
                for (final tunnel in items)
                  ListItem(
                    title: Text(tunnel.name),
                    subtitle: Text(tunnel.planName ?? '—'),
                    trailing: Text(
                      tunnel.type == 'trial'
                          ? l.ipingTunnelBatchStatusNoChange
                          : tunnel.planPrice == null
                          ? '—'
                          : ipingCurrency(tunnel.planPrice!.toDouble()),
                      style: value.copyWith(
                        color: tunnel.type == 'trial'
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(List<int> ids) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l = context.appLocalizations;
    try {
      await ref.read(ipingAuthenticatedApiProvider).batchRenewTunnels(ids);
      ref.invalidate(ipingUserInfoProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on IpingException catch (error) {
      if (!mounted) return;
      _error = _failureText(l, error, fallback: l.ipingTunnelRenewFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _BatchUpdateSheet extends ConsumerStatefulWidget {
  const _BatchUpdateSheet({required this.tunnels});

  final List<IpingTunnel> tunnels;

  @override
  ConsumerState<_BatchUpdateSheet> createState() => _BatchUpdateSheetState();
}

class _BatchUpdateSheetState extends ConsumerState<_BatchUpdateSheet> {
  String? _status;
  bool? _autoRenew;
  late final TextEditingController _ipController;
  late final TextEditingController _namePrefixController;
  late final TextEditingController _nameController;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _namePrefixController = TextEditingController();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _namePrefixController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _changed([String? _]) => setState(() => _error = null);

  List<String> get _names => _nameController.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty && mounted) {
      setState(() {
        _ipController.text = text;
        _error = null;
      });
    }
  }

  Future<void> _pickNativeIp() async {
    final proxy = await showInSheet<IpingUserProxy?>(
      context,
      builder: (_) => const _UserProxyPickerSheet(),
    );
    if (proxy == null || !mounted) return;
    final formatted = (proxy.username.isNotEmpty || proxy.password.isNotEmpty)
        ? '${proxy.host}:${proxy.port}:${proxy.username}:${proxy.password}'
        : '${proxy.host}:${proxy.port}';
    final current = _ipController.text.trim();
    setState(() {
      _ipController.text = current.isEmpty ? formatted : '$current\n$formatted';
      _error = null;
    });
  }

  void _generateNames() {
    final prefix = _namePrefixController.text.replaceFirst(RegExp(r'^\s+'), '');
    if (prefix.trim().isEmpty) return;
    final parsedIps = _parseProxyAddresses(_ipController.text);
    final count = parsedIps.isNotEmpty
        ? parsedIps.length
        : widget.tunnels.length;
    setState(() {
      _nameController.text = List.generate(
        count,
        (i) => '$prefix${i + 1}',
      ).join('\n');
      _error = null;
    });
  }

  Future<void> _submit() async {
    final l = context.appLocalizations;
    final parsedIps = _parseProxyAddresses(_ipController.text);
    final parsedNames = _names;

    final fillItems = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.tunnels.length; i++) {
      final tunnel = widget.tunnels[i];
      final name = i < parsedNames.length ? parsedNames[i] : null;
      final address = i < parsedIps.length ? parsedIps[i] : null;
      if (name == null && address == null) continue;

      final item = <String, dynamic>{'id': tunnel.id};
      if (name != null && name.isNotEmpty) {
        item['name'] = name;
      }
      if (address != null) {
        item['forward_addresses'] = {address.endpoint: 1};
        final u = address.username ?? tunnel.forwardUsername;
        final p = address.password ?? tunnel.forwardPassword;
        item['forward_addresses_protocol'] = {
          'type': 'socks5',
          if (u != null && u.isNotEmpty) 'username': u,
          if (p != null && p.isNotEmpty) 'password': p,
        };
      }
      fillItems.add(item);
    }

    final hasFieldUpdate = _status != null || _autoRenew != null;
    if (!hasFieldUpdate && fillItems.isEmpty) {
      setState(() => _error = l.ipingTunnelBatchStatusNoChange);
      return;
    }

    final lockedConflict = fillItems.any((item) {
      if (!item.containsKey('forward_addresses')) return false;
      final tunnel = widget.tunnels.firstWhere((t) => t.id == item['id']);
      if (tunnel.canChangeForwardAddress) return false;
      final newAddr =
          (item['forward_addresses'] as Map<String, dynamic>).keys.first;
      return !tunnel.forwardAddresses.containsKey(newAddr);
    });
    if (lockedConflict) {
      setState(() => _error = l.ipingTunnelForwardLocked);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(ipingAuthenticatedApiProvider);
      if (fillItems.isNotEmpty) {
        await api.batchFillTunnels(fillItems);
      }
      if (hasFieldUpdate) {
        await api.batchUpdateTunnels(
          ids: widget.tunnels.map((t) => t.id).toList(),
          status: _status,
          autoRenew: _autoRenew,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on IpingException catch (error) {
      if (!mounted) return;
      _error = _failureText(l, error, fallback: l.ipingTunnelUpdateFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _linesField({
    required Key key,
    required TextEditingController controller,
    String? hintText,
  }) => DecorationListItem(
    title: TextField(
      key: key,
      controller: controller,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      style: context.listTitleStyle.toTabular,
      onChanged: _changed,
      decoration: InputDecoration.collapsed(
        border: const NoInputBorder(),
        hintText: hintText,
      ),
    ),
  );

  String _linesFooter(AppLocalizations l, int count) {
    final hint = l.ipingTunnelBatchFillAddressesHint;
    return count == 0 ? hint : '$hint · $count / ${widget.tunnels.length}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final parsedIps = _parseProxyAddresses(_ipController.text);
    return FormPage(
      title: l.ipingTunnelBatchUpdate,
      saveLabel: l.confirm,
      saving: _submitting,
      error: _error,
      onSave: _submit,
      children: [
        AbsorbPointer(
          absorbing: _submitting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              generateSection(
                items: [
                  ListItem<String?>.options(
                    key: const ValueKey('batch-status'),
                    title: Text(l.status),
                    options: const [null, 'active', 'inactive'],
                    value: _status,
                    textBuilder: (status) => switch (status) {
                      'active' => l.ipingTunnelStatusActive,
                      'inactive' => l.ipingTunnelStatusInactive,
                      _ => l.ipingTunnelBatchStatusNoChange,
                    },
                    onChanged: (status) => setState(() {
                      _status = status;
                      _error = null;
                    }),
                  ),
                  ListItem<bool?>.options(
                    key: const ValueKey('batch-auto-renew'),
                    title: Text(l.ipingTunnelAutoRenew),
                    options: const [null, true, false],
                    value: _autoRenew,
                    textBuilder: (value) => _switchLabel(
                      l,
                      value,
                      unset: l.ipingTunnelBatchStatusNoChange,
                    ),
                    onChanged: (value) => setState(() {
                      _autoRenew = value;
                      _error = null;
                    }),
                  ),
                ],
              ),
              generateSection(
                title: l.ipingTunnelBatchFillAddresses,
                actions: [
                  IconButtonData(
                    glyph: AppGlyphs.paste,
                    tooltip: l.ipingTunnelImportClipboard,
                    onPressed: _pasteFromClipboard,
                  ),
                  IconButtonData(
                    glyph: AppGlyphs.proxies,
                    tooltip: l.ipingTunnelSelectFromNativeIps,
                    onPressed: _pickNativeIp,
                  ),
                ],
                items: [
                  _linesField(
                    key: const ValueKey('batch-update-ip-input'),
                    controller: _ipController,
                    hintText: '1.2.3.4:1080\nuser:pass@5.6.7.8:1080',
                  ),
                ],
                footer: _linesFooter(l, parsedIps.length),
              ),
              generateSection(
                title: l.ipingTunnelBatchFillNames,
                items: [
                  DecorationListItem(
                    title: TextField(
                      key: const ValueKey('batch-name-prefix-input'),
                      controller: _namePrefixController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _generateNames(),
                      decoration: InputDecoration.collapsed(
                        border: const NoInputBorder(),
                        hintText: l.ipingTunnelBatchFillNamesPrefix,
                      ),
                    ),
                    trailing: TextButton(
                      key: const ValueKey('batch-name-generate-btn'),
                      onPressed: _generateNames,
                      child: Text(l.ipingTunnelBatchFillNamesGenerate),
                    ),
                  ),
                  _linesField(
                    key: const ValueKey('batch-update-name-input'),
                    controller: _nameController,
                  ),
                ],
                footer: _linesFooter(l, _names.length),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParsedProxyAddress {
  const _ParsedProxyAddress({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String? username;
  final String? password;

  String get endpoint => '$host:$port';
}

List<_ParsedProxyAddress> _parseProxyAddresses(String text) {
  final addresses = <_ParsedProxyAddress>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final urlMatch = RegExp(
      r'^(?:[a-zA-Z0-9]+):\/\/(?:([^:]*):([^@]*)@)?(\[[^\]]+\]|[^:\s]+):(\d+)$',
    ).firstMatch(line);
    if (urlMatch != null) {
      final port = int.tryParse(urlMatch.group(4) ?? '');
      if (port != null && port >= 1 && port <= 65535) {
        final u = urlMatch.group(1);
        final p = urlMatch.group(2);
        addresses.add(
          _ParsedProxyAddress(
            host: urlMatch.group(3)!,
            port: port,
            username: (u != null && u.isNotEmpty)
                ? Uri.decodeComponent(u)
                : null,
            password: (p != null && p.isNotEmpty)
                ? Uri.decodeComponent(p)
                : null,
          ),
        );
        continue;
      }
    }

    final fieldsMatch = RegExp(
      r'^(\[[^\]]+\]|[^:\s]+):(\d+):([^:]*):(.*)$',
    ).firstMatch(line);
    if (fieldsMatch != null) {
      final port = int.tryParse(fieldsMatch.group(2) ?? '');
      if (port != null && port >= 1 && port <= 65535) {
        final u = fieldsMatch.group(3);
        final p = fieldsMatch.group(4);
        addresses.add(
          _ParsedProxyAddress(
            host: fieldsMatch.group(1)!,
            port: port,
            username: (u != null && u.isNotEmpty) ? u : null,
            password: (p != null && p.isNotEmpty) ? p : null,
          ),
        );
        continue;
      }
    }

    final authMatch = RegExp(
      r'^([^:]+):([^@]+)@(\[[^\]]+\]|[^:\s]+):(\d+)$',
    ).firstMatch(line);
    if (authMatch != null) {
      final port = int.tryParse(authMatch.group(4) ?? '');
      if (port != null && port >= 1 && port <= 65535) {
        addresses.add(
          _ParsedProxyAddress(
            host: authMatch.group(3)!,
            port: port,
            username: authMatch.group(1),
            password: authMatch.group(2),
          ),
        );
        continue;
      }
    }

    final plainMatch = RegExp(r'^(\[[^\]]+\]|[^:\s]+):(\d+)$').firstMatch(line);
    if (plainMatch != null) {
      final port = int.tryParse(plainMatch.group(2) ?? '');
      if (port != null && port >= 1 && port <= 65535) {
        addresses.add(
          _ParsedProxyAddress(host: plainMatch.group(1)!, port: port),
        );
        continue;
      }
    }
  }
  return addresses;
}
