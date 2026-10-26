import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'ip_quality_text.dart';
import 'detail.dart';

Future<void> showIpQualitySheet(BuildContext context, {required String ip}) {
  if (isSheetPage(context)) {
    return Navigator.of(
      context,
    ).push(PagedSheetRoute(builder: (_) => _IpQualitySheet(ip: ip)));
  }
  return showSheet<void>(
    context: context,
    builder: (_) => _IpQualitySheet(ip: ip),
  );
}

class _IpQualitySheet extends ConsumerWidget {
  const _IpQualitySheet({required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = context.appLocalizations;
    final isLoading = ref.watch(
      ipQualityProvider(ip).select((result) => result.isLoading),
    );
    return CommonScaffold(
      title: localizations.outboundIp,
      actions: [
        AppBarActionButton(
          data: IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: localizations.ipQualityRetry,
            isLoading: isLoading,
            onPressed: () => ref.invalidate(ipQualityProvider(ip)),
          ),
        ),
      ],
      body: _IpQualityDetail(ip: ip),
    );
  }
}

class _HideIpItem extends ConsumerWidget {
  const _HideIpItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    void update(bool value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(hideIp: value));
    return DecorationListItem(
      title: Text(context.appLocalizations.hideIp),
      onPressed: () => update(!hideIp),
      trailing: Switch(value: hideIp, onChanged: update),
    );
  }
}

class _IpQualityDetail extends ConsumerWidget {
  const _IpQualityDetail({required this.ip});
  final String ip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(ipQualityProvider(ip));
    return IpQualityDetail(
      ip: ip,
      isLoading: result.isLoading,
      quality: result.value,
      error: result.error,
      address: IpQualityText(ip: ip),
      other: const [_HideIpItem()],
    );
  }
}
