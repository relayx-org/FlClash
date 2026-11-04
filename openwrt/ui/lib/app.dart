import 'preferences.dart';
import 'package:fl_clash/ui/appearance_defaults.dart';
import 'package:fl_clash/pages/home_presentation.dart';
import 'package:fl_clash/enum/appearance.dart';
import 'package:fl_clash/iping/account_widgets.dart';
import 'package:fl_clash/enum/page_label.dart';
import 'package:fl_clash/l10n/page_labels.dart';
import 'package:fl_clash/views/page_destination.dart';
import 'dart:async';

import 'package:fl_clash/iping/login_page.dart';
import 'package:fl_clash/iping/subscription_url.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/l10n/ui_localizations.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/record.dart';
import 'package:material_ui/material_ui.dart';

import 'package:fl_clash/enum/navigation_item_mode.dart';
import 'package:fl_clash/iping/client_providers.dart';
import 'package:fl_clash/iping/native_ip_page.dart';
import 'package:fl_clash/iping/tunnel_page.dart';
import 'package:fl_clash/pages/navigation_spec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'controller.dart';
import 'iping_client.dart';
import 'pages.dart';

enum RouterAspect { session, status, telemetry, probes, proxies }

class RouterScope extends StatelessWidget {
  const RouterScope({super.key, required this.controller, required this.child});

  final RouterController controller;
  final Widget child;

  static RouterController of(BuildContext context, {RouterAspect? aspect}) =>
      InheritedModel.inheritFrom<_RouterState>(
        context,
        aspect: aspect,
      )!.controller;

  static RouterController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RouterState>()!.controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, child) => _RouterState(controller: controller, child: child!),
    child: child,
  );
}

class _RouterState extends InheritedModel<RouterAspect> {
  _RouterState({required this.controller, required super.child})
    : values = {
        RouterAspect.session: (
          controller.initialized,
          controller.status.hasSubscription,
        ),
        RouterAspect.status: (
          controller.signedIn,
          controller.status.manualSubscription,
          controller.connected,
          controller.busy,
          controller.nodes,
          controller.email,
          controller.site,
          controller.status.updated,
          controller.error,
          controller.telemetry.mode,
          controller.revision,
          controller.siteConfig,
        ),
        RouterAspect.telemetry: (
          controller.traffic.revision,
          controller.telemetry.memory,
          controller.telemetry.connections,
        ),
        RouterAspect.probes: controller.probes.revision,
        RouterAspect.proxies: (
          controller.delayRevision,
          controller.probes.outbound.route.coreEpoch,
          controller.probes.outbound.route.picksVersion,
        ),
      };

  final RouterController controller;
  final Map<RouterAspect, Object> values;

  @override
  bool updateShouldNotify(_RouterState oldWidget) => true;

  @override
  bool updateShouldNotifyDependent(
    _RouterState oldWidget,
    Set<RouterAspect> dependencies,
  ) => dependencies.any((aspect) => values[aspect] != oldWidget.values[aspect]);
}

class RouterApp extends StatefulWidget {
  const RouterApp({super.key, required this.client});

  final RouterClient client;

  @override
  State<RouterApp> createState() => RouterAppState();
}

class RouterAppState extends State<RouterApp> with WidgetsBindingObserver {
  late final RouterController _controller = RouterController(widget.client);
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _ipingClient = createRouterIpingClient(
    widget.client,
    () => _controller.site,
  );
  void _navigate(PageLabel label) {
    final navigator = _navigatorKey.currentState;
    if (label != PageLabel.tunnels || navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => const IpingTunnelsPage()));
  }

  late final preferences = RouterPreferences.fromJson(
    widget.client.readPreferences(),
  );
  int _revision = 0;
  static RouterAppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouterPreferencesScope>()!.app;
  ThemeMode get themeMode => preferences.themeMode;
  Locale? get locale => AppLocalizations.delegate.supportedLocales
      .where((value) => value.toString() == preferences.locale)
      .firstOrNull;
  LiquidGlassMode get glassMode => preferences.glass;
  bool get glass => glassMode != LiquidGlassMode.none;
  void updatePreferences(void Function(RouterPreferences value) update) {
    setState(() {
      update(preferences);
      _revision++;
      widget.client.writePreferences(preferences.toJson());
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateVisible(WidgetsBinding.instance.lifecycleState);
    unawaited(_controller.initialize());
  }

  void _updateVisible(AppLifecycleState? state) => _controller.setVisible(
    state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive,
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateVisible(state);

  void updateAppearance({
    ThemeMode? theme,
    Locale? language,
    LiquidGlassMode? liquidGlass,
  }) {
    updatePreferences((value) {
      if (theme != null) value.themeMode = theme;
      if (language != null) value.locale = language.toString();
      if (liquidGlass != null) value.glass = liquidGlass;
    });
  }

  void updateLocale(Locale? language) =>
      updatePreferences((value) => value.locale = language?.toString());

  ThemeData themeFor(Brightness brightness, {bool? pureBlack}) => ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: commonSharedXPageTransitions,
        TargetPlatform.windows: commonSharedXPageTransitions,
        TargetPlatform.linux: commonSharedXPageTransitions,
        TargetPlatform.macOS: commonSharedXPageTransitions,
      },
    ),
    colorScheme: seededColorScheme(
      seedColor: Color(preferences.primaryColor ?? defaultPrimaryColor),
      style: preferences.colorStyle,
      brightness: brightness,
    ).toPureBlack(pureBlack ?? preferences.pureBlack),
    // Web renderers cannot use system fonts; emoji fallback also widens spaces.
    fontFamily: preferences.fontFamily ?? 'Roboto',
    fontFamilyFallback: const ['Roboto'],
  ).withAppShapes.withAppSurfaces.withAppTypography;

  @override
  Widget build(BuildContext context) {
    return RouterPreferencesScope(
      app: this,
      revision: _revision,
      child: RouterScope(
        controller: _controller,
        child: ProviderScope(
          overrides: [
            ipingClientProvider.overrideWithValue(_ipingClient),
            ipingNavigateProvider.overrideWithValue(_navigate),
          ],
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'iPing',
            debugShowCheckedModeBanner: false,
            theme: themeFor(Brightness.light),
            darkTheme: themeFor(Brightness.dark),
            themeMode: themeMode,
            locale: locale,
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              AppUiLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            scrollBehavior: const BaseScrollBehavior(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  preferences.customTextScale
                      ? preferences.textScale
                      : WidgetsBinding
                            .instance
                            .platformDispatcher
                            .textScaleFactor
                            .clamp(minTextScale, maxTextScale)
                            .toDouble(),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => ViewScope(
                  size: constraints.biggest,
                  isMobile: constraints.maxWidth <= 600,
                  child: MeasureScope(
                    measure: Measure.of(
                      context,
                      MediaQuery.textScalerOf(context).scale(1),
                    ),
                    child: SurfaceScope(
                      level: SurfaceLevel.page,
                      child: LiquidGlassScope(
                        enabled: glass,
                        quality: glassMode == LiquidGlassMode.ultra
                            ? LiquidGlassQuality.ultra
                            : LiquidGlassQuality.standard,
                        child: LiquidGlassHost(
                          enabled: glass,
                          child: RecordPresentationScope(
                            onCopied: (context) =>
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context).copySuccess,
                                    ),
                                  ),
                                ),
                            child: KeyboardInsetHold(child: child!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            home: const _Gate(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
}

class RouterPreferencesScope extends InheritedWidget {
  const RouterPreferencesScope({
    super.key,
    required this.app,
    required this.revision,
    required super.child,
  });
  final RouterAppState app;
  final int revision;
  @override
  bool updateShouldNotify(RouterPreferencesScope oldWidget) =>
      revision != oldWidget.revision;
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final controller = RouterScope.of(context, aspect: RouterAspect.session);
    if (!controller.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return controller.status.hasSubscription
        ? const RouterHome()
        : const _Login();
  }
}

class _Login extends StatelessWidget {
  const _Login();

  @override
  Widget build(BuildContext context) {
    final controller = RouterScope.of(context);
    return IpingLoginPage(
      site: controller.siteConfig,
      busy: controller.busy,
      showBrowserWaiting: controller.authorizing,
      failure: controller.error == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                routerError(context, controller.error!),
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
            ),
      onSignIn: () => controller.signIn(),
      onRegister: () => controller.signIn(register: true),
      onCancel: controller.cancelSignIn,
      onImport: () => importRouterSubscription(context),
      onForgotPassword: () =>
          controller.client.open('${controller.site}/handler/forgot-password'),
      onTerms: () =>
          controller.client.open('${controller.site}/terms-of-service.html'),
      onPrivacy: () =>
          controller.client.open('${controller.site}/privacy-policy.html'),
    );
  }
}

Future<void> importRouterSubscription(BuildContext context) async {
  final controller = RouterScope.read(context);
  if (controller.busy) return;
  final l = AppLocalizations.of(context);
  final url = await showFloatingDialog<String>(
    context: context,
    child: InputDialog(
      title: l.ipingImportSubscription,
      value: '',
      labelText: l.url,
      validator: (value) =>
          isIpingSubscriptionUrl(value?.trim() ?? '') ? null : l.urlTip(l.url),
    ),
  );
  if (url != null && context.mounted) await controller.importSubscription(url);
}

class RouterHome extends StatefulWidget {
  const RouterHome({super.key});

  @override
  State<RouterHome> createState() => _RouterHomeState();
}

class _RouterHomeState extends State<RouterHome> {
  PageLabel _page = PageLabel.dashboard;
  bool _expanded = true;
  String? _shownError;

  @override
  Widget build(BuildContext context) {
    final controller = RouterScope.of(context, aspect: RouterAspect.status);
    final l = AppLocalizations.of(context);
    final mobile = context.isMobileView;
    final preferences = RouterAppState.of(context).preferences;
    final pages = <PageLabel, Widget>{
      PageLabel.dashboard: const RouterDashboard(),
      PageLabel.proxies: const RouterProxies(),
      PageLabel.connections: const RouterConnections(),
      PageLabel.logs: const RouterLogs(),
      PageLabel.tools: const RouterTools(),
      PageLabel.nativeIp: const IpingNativeIpPage(),
      PageLabel.tunnels: const IpingTunnelsPage(),
      PageLabel.account: const RouterSubscription(),
    };
    final mode = mobile
        ? NavigationItemMode.mobile
        : NavigationItemMode.desktop;
    final entries = [
      for (final label in appNavigationOrder)
        if (pages[label] case final page?)
          for (final modes in [
            navigationModesFor(
              label,
              openLogs: preferences.openLogs,
              hasProxies: true,
              signedIn: controller.signedIn,
              hasSubscription: controller.status.hasSubscription,
            ),
          ])
            if (modes.contains(mode)) (label, page),
    ];
    final selected = entries.indexWhere((entry) => entry.$1 == _page);
    final index = selected == -1 ? 0 : selected;
    final labels = [for (final entry in entries) entry.$1];
    if (entries.isNotEmpty) _page = entries[index].$1;
    final error = controller.error;
    if (error == null) _shownError = null;
    if (error != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(routerError(context, error))));
        }
      });
    }
    final body = AppPagesView(
      labels: labels,
      selectedPage: labels[index],
      mobile: mobile,
      animation: preferences.animation,
      pageBuilder: (_, pageIndex) => AppNavigationPage(
        key: ValueKey(labels[pageIndex]),
        id: labels[pageIndex],
        mobile: mobile,
        active: pageIndex == index,
        child: entries[pageIndex].$2,
      ),
    );
    return Scaffold(
      body: AppSidebarFrame(
        hasSidebar: !mobile,
        sidebar: NavigationSidebar(
          destinations: [
            for (final entry in entries)
              SidebarDestination(
                glyph: entry.$1.glyph,
                label: entry.$1.labelOf(l),
              ),
          ],
          selectedIndex: index,
          expanded: MediaQuery.sizeOf(context).width > 840 && _expanded,
          onToggle: MediaQuery.sizeOf(context).width > 840
              ? () => setState(() => _expanded = !_expanded)
              : null,
          onSelected: (selectedIndex) =>
              setState(() => _page = entries[selectedIndex].$1),
          footer: const _AccountButton(),
        ),
        child: HomeNavigationBody(
          mobile: mobile,
          floating: preferences.floatingBar,
          destinations: [
            for (final entry in entries)
              NavigationDockDestination(
                glyph: entry.$1.glyph,
                label: entry.$1.labelOf(l),
              ),
          ],
          selectedIndex: index,
          onSelected: (selectedIndex) =>
              setState(() => _page = entries[selectedIndex].$1),
          child: body,
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();
  @override
  Widget build(BuildContext context) {
    final controller = RouterScope.of(context, aspect: RouterAspect.status);
    return IpingAccountMenu(
      label: controller.signedIn
          ? controller.email
          : controller.status.manualSubscription
          ? AppLocalizations.of(context).ipingManualSubscription
          : null,
      site: controller.siteConfig,
      busy: controller.busy,
      onConsole: () => controller.client.open('${controller.site}/home'),
      onSignOut: () => controller.signOut(),
      menuBuilder: (_) => AnimatedBuilder(
        animation: controller,
        builder: (_, _) => IpingAccountActions(
          busy: controller.busy,
          onConsole: () => controller.client.open('${controller.site}/home'),
          onSignOut: () => controller.signOut(),
        ),
      ),
    );
  }
}

String routerError(BuildContext context, String error) {
  final l = AppLocalizations.of(context);
  return switch (error) {
    'not_logged_in' ||
    'login_required' ||
    'login_expired' => l.ipingSessionExpired,
    'no_nodes' => l.ipingManualNoNodes,
    'invalid_subscription' => l.ipingSubscriptionError,
    'storage_error' => l.ipingStorageError,
    'controller_unavailable' => l.memoryCoreNotRunning,
    'busy' => l.routerBusy,
    _ => error,
  };
}
