import 'package:fl_clash/iping/profile_resources_page.dart';
import 'custom_resources_page.dart';
import 'package:fl_clash/views/config/filters.dart';
import 'package:fl_clash/views/config/icon_sets.dart';
import 'package:fl_clash/views/config/providers.dart';
import 'package:fl_clash/views/profiles/custom/custom_proxies.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';

class CustomResourcesView extends ConsumerWidget {
  const CustomResourcesView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = ref.watch(ipingBackendProvider).resourceKinds;
    return CustomResourcesSettingsPage(
      application: IpingProfileResourcesPage(
        backend: ref.read(ipingBackendProvider),
      ),
      proxies: kinds.contains(IpingResourceKind.proxies)
          ? const CustomProxiesView()
          : null,
      providers: kinds.contains(IpingResourceKind.ruleProviders)
          ? const ClashProvidersView()
          : null,
      filters: kinds.contains(IpingResourceKind.filters)
          ? const FiltersView()
          : null,
      icons: kinds.contains(IpingResourceKind.iconSets)
          ? const IconSetsView()
          : null,
    );
  }
}
