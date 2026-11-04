import 'dart:async';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_sheet.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/dashboard_host.dart';
import 'package:fl_clash/iping/pages/dashboard_page.dart';
import 'package:fl_clash/iping/subscription.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/service_status.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/dashboard/widgets/widgets.dart';
import 'package:fl_clash/views/dashboard/widget_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class NativeDashboardPreferences implements IpingDashboardPreferences {
  NativeDashboardPreferences(this._ref);

  final Ref _ref;

  @override
  bool get hideIp => _ref.read(appSettingProvider).hideIp;

  @override
  List<String> get serviceOrder => _ref.read(appSettingProvider).serviceOrder;

  @override
  List<String> get disabledServices =>
      _ref.read(appSettingProvider).disabledServices;
}

class NativeDashboardOutboundProbe implements IpingDashboardOutboundProbe {
  NativeDashboardOutboundProbe(this._ref);

  final Ref _ref;

  @override
  RoutedProbeState<String, IpInfo> get state =>
      _ref.read(outboundIpProbeProvider);

  @override
  void watch(String target) =>
      _ref.read(outboundIpProbeProvider.notifier).watch(target);

  @override
  void unwatch(String target) =>
      _ref.read(outboundIpProbeProvider.notifier).unwatch(target);

  @override
  IpQuality? qualityOf(String ip) => _ref.read(ipQualityProvider(ip)).value;

  @override
  bool isQualityLoading(String ip) =>
      _ref.read(ipQualityProvider(ip)).isLoading;

  @override
  void refreshOutbound() {
    final probe = _ref.read(outboundIpProbeProvider.notifier);
    final ip = _ref.read(outboundIpProbeProvider).valueOf(routedOutbound)?.ip;
    probe.refresh(const [routedOutbound]);
    if (ip != null && _ref.read(ipQualityProvider(ip)).hasError) {
      _ref.invalidate(ipQualityProvider(ip));
    }
  }
}

class NativeDashboardServiceProbe implements IpingDashboardServiceProbe {
  NativeDashboardServiceProbe(this._ref);

  final Ref _ref;

  @override
  RoutedProbeState<ServiceTarget, ServiceCheck> get state =>
      _ref.read(serviceStatusProvider);

  @override
  void watch(ServiceTarget target) =>
      _ref.read(serviceStatusProvider.notifier).watch(target);

  @override
  void unwatch(ServiceTarget target) =>
      _ref.read(serviceStatusProvider.notifier).unwatch(target);

  @override
  void refresh(Iterable<ServiceTarget> targets) =>
      _ref.read(serviceStatusProvider.notifier).refresh(targets);
}

class NativeDashboardProbes extends ChangeNotifier
    implements IpingDashboardProbes {
  NativeDashboardProbes(this._ref)
    : outbound = NativeDashboardOutboundProbe(_ref),
      services = NativeDashboardServiceProbe(_ref) {
    _ref.listen(outboundIpProbeProvider, (_, state) {
      _watchQuality(state.valueOf(routedOutbound)?.ip);
      notifyListeners();
    }, fireImmediately: true);
    _ref.listen(serviceStatusProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  @override
  final NativeDashboardOutboundProbe outbound;
  @override
  final NativeDashboardServiceProbe services;
  ProviderSubscription<AsyncValue<IpQuality>>? _quality;
  String? _qualityIp;
  bool _disposed = false;

  @override
  Object? get error => null;

  void _watchQuality(String? ip) {
    if (_disposed || ip == _qualityIp) return;
    _quality?.close();
    _quality = null;
    _qualityIp = ip;
    if (ip == null) return;
    _quality = _ref.listen(ipQualityProvider(ip), (_, _) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _quality?.close();
    _quality = null;
    super.dispose();
  }
}

class NativeDashboardTelemetry extends ChangeNotifier {
  NativeDashboardTelemetry(this._ref) {
    _traffic = _ref.read(ipingTrafficProvider);
    _telemetry = IpingTelemetry(
      traffic: _traffic,
      mode: _ref.read(ipingModeProvider),
    );
    _ref.listen(ipingTrafficProvider, (_, traffic) {
      if (traffic.revision < _traffic.revision) return;
      _update(
        traffic: traffic,
        connections: _telemetry.connections,
        memory: _telemetry.memory,
        mode: _telemetry.mode,
      );
    });
    _ref.listen(ipingModeProvider, (_, mode) {
      _update(
        traffic: _traffic,
        connections: _telemetry.connections,
        memory: _telemetry.memory,
        mode: mode,
      );
    });
    _ref.listen(coreStatusProvider, (_, status) {
      if (status != CoreStatus.connected) {
        _update(
          traffic: _traffic,
          connections: 0,
          memory: 0,
          mode: _telemetry.mode,
        );
      } else {
        unawaited(_poll());
      }
    });
    _ref.listen(appVisibleProvider, (_, visible) {
      if (visible) unawaited(_poll());
    });
  }

  final Ref _ref;
  late IpingTrafficSnapshot _traffic;
  late IpingTelemetry _telemetry;
  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;

  IpingTrafficSnapshot get traffic => _traffic;

  IpingTelemetry get telemetry => _telemetry;

  @override
  void addListener(VoidCallback listener) {
    final wasEmpty = !hasListeners;
    super.addListener(listener);
    if (wasEmpty) _startPolling();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stopPolling();
  }

  void _startPolling() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_poll());
    });
    unawaited(_poll());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_disposed || _polling || !hasListeners) return;
    if (!_ref.read(appVisibleProvider) ||
        _ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    _polling = true;
    try {
      final next = await _ref.read(ipingBackendProvider).readTelemetry();
      if (_disposed) return;
      _update(
        traffic: next.traffic.revision >= _traffic.revision
            ? next.traffic
            : _traffic,
        connections: next.connections,
        memory: next.memory,
        mode: next.mode,
      );
    } catch (_) {
      // The dashboard keeps the last telemetry when the Core cannot answer.
    } finally {
      _polling = false;
    }
  }

  void _update({
    required IpingTrafficSnapshot traffic,
    required int connections,
    required int memory,
    required Mode mode,
  }) {
    if (_disposed) return;
    if (traffic.revision == _traffic.revision &&
        connections == _telemetry.connections &&
        memory == _telemetry.memory &&
        mode == _telemetry.mode) {
      return;
    }
    _traffic = traffic;
    _telemetry = IpingTelemetry(
      traffic: traffic,
      connections: connections,
      memory: memory,
      mode: mode,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}

class _NativeDashboardEditor implements IpingDashboardEditor {
  _NativeDashboardEditor(this._ref);

  final Ref _ref;

  static const _desktopOrder = [
    DashboardWidget.currentOutbound,
    DashboardWidget.networkSpeed,
    DashboardWidget.outboundMode,
    DashboardWidget.vpnButton,
    DashboardWidget.networkTakeover,
    DashboardWidget.connectionStats,
    DashboardWidget.proxyGroups,
    DashboardWidget.intranetIp,
    DashboardWidget.profiles,
    DashboardWidget.serviceStatus,
    DashboardWidget.memoryInfo,
  ];

  SupportPlatform get _platform => SupportPlatform.currentPlatform;

  List<DashboardWidget> get _saved =>
      _ref.read(appSettingProvider).dashboardWidgets;

  @override
  List<IpingDashboardCard> get cards => [
    for (final widget in _saved)
      if (widget.platforms.contains(_platform)) _cardOf(widget),
  ];

  @override
  List<IpingDashboardCard> get available => [
    for (final widget in DashboardWidget.values)
      if (widget.platforms.contains(_platform) && !_saved.contains(widget))
        _cardOf(widget),
  ];

  @override
  List<IpingDashboardCard> get desktopCards => [
    for (final widget in _desktopOrder)
      if (widget.platforms.contains(_platform)) _cardOf(widget),
    // A phone-sized platform has no takeover card, so the wide layout keeps
    // the VPN switch where the old dashboard put it.
    if (_platform == SupportPlatform.IOS) _vpnControl,
  ];

  static final _vpnControl = IpingDashboardCard(
    id: 'vpnControl',
    label: (_) => 'VPN',
    builder: (_) => const VpnCard(),
    desktop: const [
      IpingDashboardDesktopCard(
        area: IpingDashboardDesktopArea.control,
        builder: _vpnTile,
        span: 2,
      ),
    ],
  );

  @override
  void save(List<String> ids) {
    final byName = DashboardWidget.values.asNameMap();
    final shown = [for (final id in ids) byName[id]].nonNulls.toList();
    _ref
        .read(appSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            dashboardWidgets: _keepingOtherPlatforms(
              state.dashboardWidgets,
              shown,
            ),
          ),
        );
  }

  @override
  void reset() => _ref
      .read(appSettingProvider.notifier)
      .update(
        (state) => state.copyWith(dashboardWidgets: defaultDashboardWidgets),
      );

  /// Cards this platform cannot show stay where they were among the rest.
  List<DashboardWidget> _keepingOtherPlatforms(
    List<DashboardWidget> saved,
    List<DashboardWidget> shown,
  ) {
    final result = [...shown];
    var at = 0;
    for (final card in saved) {
      if (card.platforms.contains(_platform)) {
        final index = result.indexOf(card);
        if (index != -1) at = index + 1;
      } else {
        result.insert(at++, card);
      }
    }
    return result;
  }

  IpingDashboardCard _cardOf(DashboardWidget widget) => IpingDashboardCard(
    id: widget.name,
    label: (context) => widget.label(context),
    description: (context) => widget.description(context),
    glyph: widget.glyph,
    removable: widget.removable,
    builder: (_) => widget.card,
    desktop: _desktopOf(widget),
  );

  List<IpingDashboardDesktopCard> _desktopOf(DashboardWidget widget) =>
      switch (widget) {
        DashboardWidget.currentOutbound => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.outbound,
            builder: _currentOutbound,
          ),
        ],
        DashboardWidget.networkSpeed => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.upload,
            builder: _uploadSpeed,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.download,
            builder: _downloadSpeed,
          ),
        ],
        DashboardWidget.outboundMode => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.mode,
            builder: _modeBar,
          ),
        ],
        DashboardWidget.vpnButton => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.control,
            builder: _vpnTile,
            span: 2,
          ),
        ],
        DashboardWidget.networkTakeover => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.control,
            builder: _systemProxyTile,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.control,
            builder: _tunTile,
          ),
        ],
        DashboardWidget.connectionStats => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.summary,
            builder: _connectionStatsCard,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.table,
            builder: _connectionsTableCard,
            span: 3,
          ),
        ],
        DashboardWidget.proxyGroups => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.summary,
            builder: _proxyGroupsSummary,
          ),
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.table,
            builder: _proxyGroupsCard,
            span: 2,
          ),
        ],
        DashboardWidget.intranetIp => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: _intranetCard,
          ),
        ],
        DashboardWidget.profiles => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: _profilesCard,
          ),
        ],
        DashboardWidget.serviceStatus => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: _serviceStatusCard,
          ),
        ],
        DashboardWidget.memoryInfo => const [
          IpingDashboardDesktopCard(
            area: IpingDashboardDesktopArea.middle,
            builder: _memoryCard,
          ),
        ],
      };

  static Widget _currentOutbound(BuildContext context) =>
      const CurrentOutboundCard();

  static Widget _uploadSpeed(BuildContext context) =>
      const SpeedCard(direction: TrafficDirection.upload);

  static Widget _downloadSpeed(BuildContext context) =>
      const SpeedCard(direction: TrafficDirection.download);

  static Widget _modeBar(BuildContext context) => const OutboundModeBar();

  static Widget _vpnTile(BuildContext context) => const VpnTile();

  static Widget _systemProxyTile(BuildContext context) =>
      const NetworkTakeoverTile(TakeoverSwitch.systemProxy);

  static Widget _tunTile(BuildContext context) =>
      const NetworkTakeoverTile(TakeoverSwitch.tun);

  static Widget _connectionStatsCard(BuildContext context) =>
      const ConnectionStatsCard();

  static Widget _connectionsTableCard(BuildContext context) =>
      const ConnectionsTableCard();

  static Widget _proxyGroupsSummary(BuildContext context) =>
      const ProxyGroupsSummaryCard();

  static Widget _proxyGroupsCard(BuildContext context) =>
      const ProxyGroupsCard();

  static Widget _intranetCard(BuildContext context) => const IntranetIpCard();

  static Widget _profilesCard(BuildContext context) => const ProfilesCard();

  static Widget _serviceStatusCard(BuildContext context) =>
      const ServiceStatusCard();

  static Widget _memoryCard(BuildContext context) => const MemoryInfo();
}

class NativeDashboardHost extends ChangeNotifier implements IpingDashboardHost {
  NativeDashboardHost(this._ref)
    : preferences = NativeDashboardPreferences(_ref),
      probes = NativeDashboardProbes(_ref),
      telemetryUpdates = NativeDashboardTelemetry(_ref),
      dashboardEditor = _NativeDashboardEditor(_ref);

  final Ref _ref;
  @override
  final NativeDashboardPreferences preferences;
  @override
  final NativeDashboardProbes probes;
  @override
  final NativeDashboardTelemetry telemetryUpdates;
  @override
  final IpingDashboardEditor dashboardEditor;
  int _revision = 0;

  int get revision => _revision;

  void refresh() {
    _revision++;
    notifyListeners();
  }

  @override
  IpingBackend get backend => _ref.read(ipingBackendProvider);

  @override
  IpingBackendState get state => _ref.read(ipingBackendStateProvider);

  @override
  bool get connected => _ref.read(coreStatusProvider) == CoreStatus.connected;

  @override
  bool get busy => state.busy;

  @override
  bool get visible => _ref.read(appVisibleProvider);

  @override
  bool get suspended => _ref.read(suspendProvider);

  @override
  bool get hasSubscription => state.hasSubscription;

  @override
  int get nodes => state.nodes;

  @override
  DateTime? get updated => state.updated;

  @override
  IpingTrafficSnapshot get traffic => telemetryUpdates.traffic;

  @override
  IpingTelemetry get telemetry => telemetryUpdates.telemetry;

  @override
  Future<IpingDashboardSnapshot> readDashboard() => backend.readDashboard();

  @override
  Future<void> synchronize() => backend.synchronize();

  @override
  Future<void> setConnected(bool value) async {
    await backend.setConnected(value);
  }

  @override
  Future<void> setMode(Mode mode) => backend.setMode(mode);

  @override
  Future<void> saveSettings(Map<String, Object?> changes) =>
      backend.updateSettings(changes);

  @override
  String errorText(BuildContext context, Object error) =>
      userFacingErrorMessage(error, AppLocalizations.of(context));

  @override
  void openSubscription(BuildContext context) => unawaited(
    showSheet<void>(
      context: context,
      builder: (_) => const IpingSubscriptionDetails(),
    ),
  );

  @override
  void openProxies(BuildContext context) =>
      unawaited(showProxiesSheet(context));

  @override
  void openConnections(BuildContext context) =>
      openDashboardFeed(context, DashboardFeed.connections);

  @override
  void openServices(BuildContext context) =>
      unawaited(showServiceStatusSheet(context));

  @override
  void openNetwork(BuildContext context) => unawaited(
    showSheet<void>(
      context: context,
      builder: (sheetContext) => CommonScaffold(
        title: AppLocalizations.of(sheetContext).network,
        body: const NetworkListView(),
      ),
    ),
  );

  @override
  void openIpQuality(BuildContext context, String ip) =>
      unawaited(showIpQualitySheet(context, ip: ip));

  @override
  void dispose() {
    probes.dispose();
    telemetryUpdates.dispose();
    super.dispose();
  }
}

class NativeDashboardRoute extends ConsumerWidget {
  const NativeDashboardRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(_nativeDashboardHostProvider);
    ref.listen(ipingBackendStateProvider, (_, _) => host.refresh());
    ref.listen(coreStatusProvider, (_, _) => host.refresh());
    ref.listen(appVisibleProvider, (_, _) => host.refresh());
    ref.listen(appSettingProvider, (_, _) => host.refresh());
    return IpingDashboardScope(host: host, child: const IpingDashboardPage());
  }
}

final _nativeDashboardHostProvider = Provider.autoDispose<NativeDashboardHost>((
  ref,
) {
  final host = NativeDashboardHost(ref);
  ref.onDispose(host.dispose);
  return host;
});
