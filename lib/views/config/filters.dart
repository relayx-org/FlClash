import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/filters_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class FiltersView extends ConsumerWidget {
  const FiltersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      IpingFiltersPage(store: ref.watch(ipingBackendProvider).filters);
}
