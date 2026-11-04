import 'package:fl_clash/iping/managed_resources_page.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';

class RouterResources extends StatelessWidget {
  const RouterResources({super.key});

  @override
  Widget build(BuildContext context) {
    final client = RouterScope.read(context).client;
    return IpingManagedResourcesPage(
      loader: () async {
        final result = await client.call('resources');
        final data = result is Map ? result['items'] : null;
        return [
          for (final item in data as List? ?? const [])
            if (item is Map)
              IpingManagedResource.fromJson(Map<String, Object?>.from(item)),
        ];
      },
      onRefresh: () => client.call('resources', const {'action': 'refresh'}),
    );
  }
}
