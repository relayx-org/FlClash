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
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/l10n/ui_localizations.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/record.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'client.dart';
import 'controller.dart';
import 'pages.dart';

class RouterScope extends InheritedNotifier<RouterController> {
  const RouterScope({
    super.key,
    required RouterController controller,
    required super.child,
  }) : super(notifier: controller);

  static RouterController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouterScope>()!.notifier!;
}

class RouterApp extends StatefulWidget {
  const RouterApp({super.key, required this.client});

  final RouterClient client;

  @override
  State<RouterApp> createState() => RouterAppState();
}

class RouterAppState extends State<RouterApp> {
  late final RouterController _controller = RouterController(widget.client);
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
    unawaited(_controller.initialize());
  }

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
    fontFamily: preferences.fontFamily,
    fontFamilyFallback: appFontFamilyFallback(
      platform: defaultTargetPlatform,
      locales: [?locale, ...WidgetsBinding.instance.platformDispatcher.locales],
    ),
  ).withAppShapes.withAppSurfaces.withAppTypography;

  @override
  Widget build(BuildContext context) {
    return RouterPreferencesScope(
      app: this,
      revision: _revision,
      child: RouterScope(
        controller: _controller,
        child: MaterialApp(
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
                    : WidgetsBinding.instance.platformDispatcher.textScaleFactor
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
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
    );
  }

  @override
  void dispose() {
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
    final controller = RouterScope.of(context);
    if (!controller.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return controller.signedIn ? const RouterHome() : const _Login();
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
      onForgotPassword: () =>
          controller.client.open('${controller.site}/handler/forgot-password'),
      onTerms: () =>
          controller.client.open('${controller.site}/terms-of-service.html'),
      onPrivacy: () =>
          controller.client.open('${controller.site}/privacy-policy.html'),
    );
  }
}

class RouterHome extends StatefulWidget {
  const RouterHome({super.key});

  @override
  State<RouterHome> createState() => _RouterHomeState();
}

class _RouterHomeState extends State<RouterHome> {
  int _page = 0;
  bool _expanded = true;
  String? _shownError;

  @override
  Widget build(BuildContext context) {
    final controller = RouterScope.of(context);
    final l = AppLocalizations.of(context);
    final mobile = context.isMobileView;
    final preferences = RouterAppState.of(context).preferences;
    final items = [
      (PageLabel.dashboard.glyph, PageLabel.dashboard.labelOf(l), 0),
      (PageLabel.proxies.glyph, PageLabel.proxies.labelOf(l), 1),
      if (!mobile)
        (PageLabel.connections.glyph, PageLabel.connections.labelOf(l), 2),
      if (!mobile && preferences.openLogs)
        (PageLabel.logs.glyph, PageLabel.logs.labelOf(l), 4),
      (PageLabel.tools.glyph, PageLabel.tools.labelOf(l), 3),
    ];
    final page = mobile && (_page == 2 || _page == 4)
        ? 3
        : _page == 4 && !preferences.openLogs
        ? 0
        : _page;
    final selected = items.indexWhere((item) => item.$3 == page);
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
    final pages = [
      const RouterDashboard(),
      const RouterProxies(),
      const RouterConnections(),
      const RouterTools(),
      const RouterLogs(),
    ];
    final labels = [
      PageLabel.dashboard,
      PageLabel.proxies,
      if (!mobile) PageLabel.connections,
      if (!mobile && preferences.openLogs) PageLabel.logs,
      PageLabel.tools,
    ];
    final body = AppPagesView(
      labels: labels,
      selectedPage: labels[selected],
      mobile: mobile,
      animation: preferences.animation,
      pageBuilder: (_, index) => AppNavigationPage(
        key: ValueKey(labels[index]),
        id: labels[index],
        mobile: mobile,
        active: index == selected,
        child: pages[items[index].$3],
      ),
    );
    return Scaffold(
      body: AppSidebarFrame(
        hasSidebar: !mobile,
        sidebar: NavigationSidebar(
          destinations: [
            for (final item in items)
              SidebarDestination(glyph: item.$1, label: item.$2),
          ],
          selectedIndex: selected,
          expanded: MediaQuery.sizeOf(context).width > 840 && _expanded,
          onToggle: MediaQuery.sizeOf(context).width > 840
              ? () => setState(() => _expanded = !_expanded)
              : null,
          onSelected: (index) => setState(() => _page = items[index].$3),
          footer: const _AccountButton(),
        ),
        child: HomeNavigationBody(
          mobile: mobile,
          floating: preferences.floatingBar,
          destinations: [
            for (final item in items)
              NavigationDockDestination(glyph: item.$1, label: item.$2),
          ],
          selectedIndex: selected,
          onSelected: (index) => setState(() => _page = items[index].$3),
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
    final controller = RouterScope.of(context);
    return IpingAccountMenu(
      email: controller.email,
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
    'no_nodes' => l.ipingNoNodes,
    'invalid_subscription' => l.ipingSubscriptionError,
    'storage_error' => l.ipingStorageError,
    'controller_unavailable' => l.memoryCoreNotRunning,
    _ => error,
  };
}
