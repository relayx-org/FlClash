import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../enum/page_label.dart';
import '../l10n/l10n.dart';
import '../l10n/page_labels.dart';
import '../ui/error_banner.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

class IpingManagedResource {
  const IpingManagedResource({
    required this.id,
    required this.category,
    required this.name,
    required this.path,
    this.size = 0,
    this.modified,
    this.virtual = false,
  });

  final String id;
  final String category;
  final String name;
  final String path;
  final int size;
  final DateTime? modified;
  final bool virtual;

  factory IpingManagedResource.fromJson(Map<String, Object?> json) =>
      IpingManagedResource(
        id: json['id'] as String? ?? '',
        category: json['category'] as String? ?? '',
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.tryParse(json['modified'] as String? ?? ''),
        virtual: json['virtual'] == true,
      );
}

typedef IpingManagedResourcesLoader =
    Future<List<IpingManagedResource>> Function();
typedef IpingManagedResourcesRefresh = Future<void> Function();

class IpingManagedResourcesPage extends StatefulWidget {
  const IpingManagedResourcesPage({
    super.key,
    required this.loader,
    this.onRefresh,
  });

  final IpingManagedResourcesLoader loader;
  final IpingManagedResourcesRefresh? onRefresh;

  @override
  State<IpingManagedResourcesPage> createState() =>
      _IpingManagedResourcesPageState();
}

class _IpingManagedResourcesPageState extends State<IpingManagedResourcesPage> {
  List<IpingManagedResource> _items = const [];
  String? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final refresh = widget.onRefresh;
    if (_refreshing) return;
    if (refresh == null) {
      await _load();
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await refresh();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = <String, List<IpingManagedResource>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    return CommonScaffold(
      title: PageLabel.resources.labelOf(l),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sync,
          tooltip: l.update,
          isLoading: _refreshing,
          onPressed: _loading ? null : _refresh,
        ),
      ],
      body: _loading && _items.isEmpty
          ? const Center(child: CommonCircleLoading())
          : _error != null && _items.isEmpty
          ? ErrorBanner(message: _error!)
          : _items.isEmpty
          ? Center(
              child: Text(
                l.emptyTip(PageLabel.resources.labelOf(l)),
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_error != null) ErrorBanner(message: _error),
                for (final entry in groups.entries)
                  generateSection(
                    title: _categoryLabel(l, entry.key),
                    items: [
                      for (final item in entry.value)
                        _IpingManagedResourceTile(resource: item),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _IpingManagedResourceTile extends StatelessWidget {
  const _IpingManagedResourceTile({required this.resource});

  final IpingManagedResource resource;

  @override
  Widget build(BuildContext context) {
    final modified = resource.modified;
    final details = [
      resource.path,
      _formatSize(resource.size),
      if (modified != null) _formatTime(modified),
    ].join(' · ');
    return ListItem(
      leading: GlyphIcon(_categoryGlyph(resource.category)),
      title: Text(resource.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

String _categoryLabel(AppLocalizations l, String category) =>
    switch (category) {
      'geo' => l.geoResources,
      'rule-provider' => l.ruleProviders,
      'proxy-provider' => l.proxyProviders,
      'cache' => l.cache,
      'script' => l.script,
      _ => category,
    };

Glyph _categoryGlyph(String category) => switch (category) {
  'geo' => AppGlyphs.resources,
  'rule-provider' => AppGlyphs.filter,
  'proxy-provider' => AppGlyphs.proxies,
  'script' => AppGlyphs.code,
  _ => AppGlyphs.layers,
};

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
