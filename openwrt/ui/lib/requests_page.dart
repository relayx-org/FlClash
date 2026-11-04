import 'dart:async';

import 'package:fl_clash/enum/page_label.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/l10n/page_labels.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

class RouterRequests extends StatefulWidget {
  const RouterRequests({super.key});

  @override
  State<RouterRequests> createState() => _RouterRequestsState();
}

class _RouterRequestsState extends State<RouterRequests> {
  Timer? _timer;
  List<Map<String, Object?>> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final result = await RouterScope.read(context).client.call('requests');
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in (result as List? ?? const []))
            if (item is Map) Map<String, Object?>.from(item),
        ];
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    return CommonScaffold(
      title: PageLabel.requests.labelOf(l),
      body: _loading
          ? const Center(child: CommonCircleLoading())
          : _error != null && items.isEmpty
          ? ErrorBanner(message: _error!)
          : items.isEmpty
          ? Center(
              child: Text(
                l.emptyTip(PageLabel.requests.labelOf(l)),
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _RequestTile(item: items[index]),
            ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final host = (item['host'] as String?)?.trim();
    final destination = item['destination'] as String? ?? '';
    final source = item['source'] as String? ?? '';
    final rule = item['rule'] as String? ?? '';
    final chains = (item['chains'] as List? ?? const []).join(' → ');
    final traffic =
        '${_size(item['download'] as num? ?? 0)} ↓ / ${_size(item['upload'] as num? ?? 0)} ↑';
    final seconds = item['duration'] as num? ?? 0;
    final detail = [
      if (source.isNotEmpty) source,
      if (rule.isNotEmpty) rule,
      if (chains.isNotEmpty) chains,
      traffic,
      '${seconds.toInt()}s',
      if (item['closed'] == true) 'closed',
    ].join(' · ');
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              host == null || host.isEmpty ? destination : host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _size(num bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
