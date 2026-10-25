import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void selectGroupProxy(
  WidgetRef ref, {
  required String groupName,
  required GroupType groupType,
  required String proxyName,
}) {
  final nextProxyName = ipingProxySelection(
    type: groupType.name,
    name: proxyName,
    pinned: ref.read(proxyNameProvider(groupName)) ?? '',
  );
  if (nextProxyName != null) {
    ref
        .read(proxiesActionProvider.notifier)
        .changeProxyDebounce(groupName, nextProxyName);
    return;
  }
  dialogs.showNotifier(
    currentAppLocalizations.notSelectedTip,
    level: MessageLevel.warning,
  );
}

class ProxyCard extends ConsumerWidget {
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inUse = ref.watch(
      selectedProxyNameProvider(groupName).select((name) => name == proxy.name),
    );
    final pinned =
        groupType.isComputedSelected &&
        ref.watch(
          proxyNameProvider(groupName).select((name) => name == proxy.name),
        );
    final isGroup = GroupType.values.any((type) => type.name == proxy.type);
    final selected = type == ProxyCardType.loose && isGroup
        ? ref.watch(
            realSelectedProxyStateProvider(
              proxy.name,
            ).select((state) => state.proxyName),
          )
        : proxy.name;
    return ProxyNodeCard(
      key: key,
      name: proxy.name,
      description: selected == proxy.name
          ? proxy.type
          : '${proxy.type}($selected)',
      compact: type == ProxyCardType.compact,
      loose: type == ProxyCardType.loose,
      inUse: inUse,
      pinned: pinned,
      latency: _DelayText(
        proxy: proxy,
        testUrl: testUrl,
        alignment: type == ProxyCardType.loose
            ? Alignment.centerLeft
            : Alignment.centerRight,
      ),
      onPressed: () => selectGroupProxy(
        ref,
        groupName: groupName,
        groupType: groupType,
        proxyName: proxy.name,
      ),
    );
  }
}

class _DelayText extends ConsumerWidget {
  const _DelayText({
    required this.proxy,
    required this.testUrl,
    required this.alignment,
  });

  final Proxy proxy;
  final String? testUrl;
  final Alignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final phase = ref.watch(
      delayTestPhaseProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    return ProxyLatency(
      delay: delay,
      phase: switch (phase) {
        DelayTestPhase.queued => ProxyLatencyPhase.queued,
        DelayTestPhase.running => ProxyLatencyPhase.running,
        null => null,
      },
      alignment: alignment,
      tooltip: context.appLocalizations.delayTest,
      failureText: delay == null
          ? ''
          : delayFailureText(delay, context.appLocalizations),
      onPressed: () => ref
          .read(proxiesActionProvider.notifier)
          .proxyDelayTest(proxy, testUrl),
    );
  }
}
