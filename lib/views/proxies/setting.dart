import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/config.dart';
import '../../ui/proxy_style.dart';
import 'page_presentation.dart';

class ProxiesSetting extends ConsumerWidget {
  const ProxiesSetting({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(proxiesStyleSettingProvider);
    return ProxiesSettingsBody(
      value: ProxyViewPreferences(
        type: value.type,
        sort: value.sortType,
        layout: value.layout,
        icon: value.iconStyle,
        card: value.cardType,
        hideTimeout: value.hideTimeoutProxies,
      ),
      onChanged: (value) => ref
          .read(proxiesStyleSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              type: value.type,
              sortType: value.sort,
              layout: value.layout,
              iconStyle: value.icon,
              cardType: value.card,
              hideTimeoutProxies: value.hideTimeout,
            ),
          ),
    );
  }
}
