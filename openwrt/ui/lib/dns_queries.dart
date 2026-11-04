import 'package:fl_clash/iping/dns_queries_page.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

class RouterDnsQueries extends StatelessWidget {
  const RouterDnsQueries({super.key});

  @override
  Widget build(BuildContext context) {
    final client = RouterScope.read(context).client;
    return IpingDnsQueriesPage(
      loader: () async {
        final result = await client.call('dns_queries');
        final data = result is Map ? result['items'] : null;
        return [
          for (final item in data as List? ?? const [])
            if (item is Map)
              IpingDnsQuery.fromJson(Map<String, Object?>.from(item)),
        ];
      },
    );
  }
}
