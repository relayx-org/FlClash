import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../enum/page_label.dart';
import '../l10n/l10n.dart';
import '../l10n/page_labels.dart';
import '../ui/error_banner.dart';
import '../ui/icons/icons.dart';
import '../ui/ui.dart';

class IpingDnsQuery {
  const IpingDnsQuery({
    required this.domain,
    required this.type,
    required this.time,
    this.initiator = '',
    this.upstream = '',
    this.cached = false,
    this.answers = const [],
    this.rcode = '',
    this.error = '',
    this.delay = 0,
    this.client = '',
    this.protocol = '',
  });

  final String domain;
  final String type;
  final DateTime time;
  final String initiator;
  final String upstream;
  final bool cached;
  final List<String> answers;
  final String rcode;
  final String error;
  final int delay;
  final String client;
  final String protocol;

  bool get isFailed =>
      error.isNotEmpty || (rcode.isNotEmpty && rcode != 'NOERROR');

  String get summary => error.isNotEmpty ? error : answers.join(', ');

  factory IpingDnsQuery.fromJson(Map<String, Object?> json) {
    final time = DateTime.tryParse(json['time'] as String? ?? '');
    return IpingDnsQuery(
      domain: json['domain'] as String? ?? '',
      type: json['type'] as String? ?? '',
      time: time ?? DateTime.fromMillisecondsSinceEpoch(0),
      initiator: json['initiator'] as String? ?? '',
      upstream: json['upstream'] as String? ?? '',
      cached: json['cached'] == true,
      answers: [
        for (final answer in json['answers'] as List? ?? const [])
          if (answer is String) answer,
      ],
      rcode: json['rcode'] as String? ?? '',
      error: json['error'] as String? ?? '',
      delay: (json['delay'] as num?)?.toInt() ?? 0,
      client: json['client'] as String? ?? '',
      protocol: json['protocol'] as String? ?? '',
    );
  }
}

typedef IpingDnsQueriesLoader = Future<List<IpingDnsQuery>> Function();

class IpingDnsQueriesPage extends StatefulWidget {
  const IpingDnsQueriesPage({
    super.key,
    required this.loader,
    this.refreshInterval = const Duration(seconds: 3),
  });

  final IpingDnsQueriesLoader loader;
  final Duration? refreshInterval;

  @override
  State<IpingDnsQueriesPage> createState() => _IpingDnsQueriesPageState();
}

class _IpingDnsQueriesPageState extends State<IpingDnsQueriesPage> {
  Timer? _timer;
  List<IpingDnsQuery> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    final interval = widget.refreshInterval;
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => _load());
    }
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: PageLabel.dns.labelOf(l),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sync,
          tooltip: l.update,
          isLoading: _loading,
          onPressed: _load,
        ),
      ],
      body: _loading && _items.isEmpty
          ? const Center(child: CommonCircleLoading())
          : _error != null && _items.isEmpty
          ? ErrorBanner(message: _error!)
          : _items.isEmpty
          ? Center(
              child: Text(
                l.emptyTip(PageLabel.dns.labelOf(l)),
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _IpingDnsQueryTile(query: _items[index]),
            ),
    );
  }
}

class _IpingDnsQueryTile extends StatelessWidget {
  const _IpingDnsQueryTile({required this.query});

  final IpingDnsQuery query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final summary = query.summary;
    final metadata = [
      if (query.client.isNotEmpty) query.client,
      if (query.upstream.isNotEmpty) query.upstream,
      '${query.delay} ms',
      _formatTime(query.time),
    ].join(' · ');
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    query.domain.isEmpty ? '-' : query.domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.headline.of(context),
                  ),
                ),
                Text(
                  query.type,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.primary),
                ),
              ],
            ),
            if (summary.isNotEmpty)
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(
                      color: query.isFailed
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (query.cached)
                  _Tag(label: AppLocalizations.of(context).cache),
                if (query.isFailed)
                  _Tag(
                    label: query.rcode.isEmpty ? 'ERROR' : query.rcode,
                    color: colorScheme.error,
                  ),
                if (query.protocol.isNotEmpty)
                  _Tag(label: query.protocol.toUpperCase()),
                Text(
                  metadata,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyle.footnote
        .of(context)
        .copyWith(color: color ?? context.colorScheme.primary),
  );
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute:$second';
}
