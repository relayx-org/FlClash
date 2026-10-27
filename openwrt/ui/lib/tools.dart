import 'settings.dart';
import 'package:fl_clash/features/logs/controller.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/widgets/appearance_controls.dart';
import 'package:fl_clash/ui/appearance_defaults.dart';
import 'package:fl_clash/views/logs_page.dart';
import 'package:fl_clash/iping/account_widgets.dart';
import 'package:fl_clash/iping/about_widgets.dart';
import 'package:fl_clash/enum/page_label.dart';
import 'package:fl_clash/l10n/page_labels.dart';
import 'package:fl_clash/views/page_destination.dart';
import 'package:fl_clash/views/settings_page.dart';
import 'package:fl_clash/iping/subscription_page.dart';
import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'pages.dart';

class RouterTools extends StatelessWidget {
  const RouterTools({super.key});
  @override
  Widget build(BuildContext context) {
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    final app = RouterAppState.of(context);
    return SettingsPage(
      account: context.isMobileView && router.signedIn
          ? IpingAccountSummary(
              email: router.email,
              site: router.siteConfig,
              busy: router.busy,
              onConsole: () => router.client.open('${router.site}/home'),
              onSignOut: () => router.signOut(),
            )
          : null,
      more: [
        if (context.isMobileView)
          SettingsRouteLink(
            glyph: PageLabel.connections.glyph,
            title: PageLabel.connections.labelOf(AppLocalizations.of(context)),
            pageBuilder: (_) => const RouterConnections(),
            forceFull: true,
          ),
        if (context.isMobileView || !app.preferences.openLogs)
          SettingsRouteLink(
            glyph: PageLabel.logs.glyph,
            title: PageLabel.logs.labelOf(AppLocalizations.of(context)),
            pageBuilder: (_) => const RouterLogs(),
            forceFull: true,
          ),
      ],
      locale: app.locale,
      onLocaleChanged: app.updateLocale,
      themeBuilder: (_) => const RouterAppearance(),
      platformSettings: [
        SettingsRouteLink(
          glyph: AppGlyphs.settings,
          title: AppLocalizations.of(context).general,
          pageBuilder: (_) =>
              const RouterCoreSettings(kind: RouterSettingsKind.general),
        ),
        SettingsRouteLink(
          glyph: AppGlyphs.code,
          title: AppLocalizations.of(context).advancedConfig,
          pageBuilder: (_) => const RouterAdvanced(),
        ),
        SettingsRouteLink(
          glyph: AppGlyphs.resources,
          title: AppLocalizations.of(context).customProfileResources,
          pageBuilder: (_) => const RouterCustomResources(),
        ),
      ],
      about: IpingAboutSummary(
        site: router.siteConfig,
        version: '0.1.0-r3',
        onTerms: () =>
            router.client.open('${router.site}/terms-of-service.html'),
        onPrivacy: () =>
            router.client.open('${router.site}/privacy-policy.html'),
      ),
    );
  }
}

class RouterAppearance extends StatelessWidget {
  const RouterAppearance({super.key});
  @override
  Widget build(BuildContext context) {
    final app = RouterAppState.of(context);
    return AppearanceSettingsPage(
      mode: app.themeMode,
      lightScheme: app.themeFor(Brightness.light).colorScheme,
      darkScheme: app.themeFor(Brightness.dark).colorScheme,
      currentScheme: context.colorScheme,
      floatingBar: app.preferences.floatingBar,
      tabAnimation: app.preferences.animation,
      glass: app.glassMode,
      onModeChanged: (value) => app.updateAppearance(theme: value),
      onGlassChanged: (value) => app.updateAppearance(liquidGlass: value),
      pureBlack: PureBlackChoice(
        value: app.preferences.pureBlack,
        standardScheme: app
            .themeFor(Brightness.dark, pureBlack: false)
            .colorScheme,
        blackScheme: app.themeFor(Brightness.dark, pureBlack: true).colorScheme,
        floatingBar: app.preferences.floatingBar,
        liquidGlass: app.glass,
        onChanged: (value) =>
            app.updatePreferences((settings) => settings.pureBlack = value),
      ),
      primaryColor: AppearancePaletteControl(
        value: AppearancePalette(
          primaryColor: app.preferences.primaryColor,
          primaryColors: app.preferences.primaryColors,
          colorStyle: app.preferences.colorStyle,
        ),
        systemColor: const Color(defaultPrimaryColor),
        floatingBar: app.preferences.floatingBar,
        liquidGlass: app.glass,
        pureBlack: app.preferences.pureBlack,
        onChanged: (value) => app.updatePreferences((settings) {
          settings.primaryColor = value.primaryColor;
          settings.primaryColors = value.primaryColors;
          settings.colorStyle = value.colorStyle;
        }),
      ),
      navigationBar: NavigationBarChoice(
        value: app.preferences.floatingBar,
        liquidGlass: app.glass,
        onChanged: (value) =>
            app.updatePreferences((settings) => settings.floatingBar = value),
      ),
      tabAnimationControl: TabAnimationChoice(
        value: app.preferences.animation,
        floatingBar: app.preferences.floatingBar,
        liquidGlass: app.glass,
        onChanged: (value) =>
            app.updatePreferences((settings) => settings.animation = value),
      ),
      textScale: TextScaleControl(
        enabled: app.preferences.customTextScale,
        scale: app.preferences.textScale,
        systemScale: WidgetsBinding.instance.platformDispatcher.textScaleFactor,
        onChanged: (enabled, scale) => app.updatePreferences((settings) {
          settings.customTextScale = enabled;
          settings.textScale = scale;
        }),
      ),
      fontFamily: AppearanceFontControl(
        fontFamily: app.preferences.fontFamily,
        label: app.preferences.fontFamily == null
            ? AppLocalizations.of(context).defaultText
            : 'JetBrains Mono',
        pageBuilder: (_) => const RouterFontFamily(),
      ),
    );
  }
}

class RouterSubscription extends StatelessWidget {
  const RouterSubscription({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = RouterScope.of(context, aspect: RouterAspect.status);
    final updated = router.status.updated;
    return IpingSubscriptionPage(
      nodes: router.nodes,
      busy: router.busy,
      failure: router.error == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                routerError(context, router.error!),
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
            ),
      updatedText: updated == null
          ? null
          : l.profileUpdatedAt(updated.toLocal().toString()),
      onSync: () => router.synchronize(),
      manualSubscription: router.status.manualSubscription,
      onImport: () => importRouterSubscription(context),
      onSignIn: router.signedIn ? null : () => router.signIn(),
      onConsole: router.signedIn
          ? () => router.client.open('${router.site}/home')
          : null,
    );
  }
}

class RouterLogs extends StatefulWidget {
  const RouterLogs({super.key});

  @override
  State<RouterLogs> createState() => _RouterLogsState();
}

class _RouterLogsState extends State<RouterLogs> with RouteMotionHoldMixin {
  late final ScrollController _scroll = sheetScrollController(
    context,
    initialScrollOffset: double.maxFinite,
  );
  late final ScrollPhysics _physics = FollowEndScrollPhysics(
    isFollowing: () => !_paused,
  );
  final _list = LogListController();

  Timer? _timer;
  bool _initialized = false;
  bool _loading = false;
  bool get _paused => !_list.value.autoScrollToEnd;
  bool _loaded = false;
  IpingLogSnapshot _snapshot = const IpingLogSnapshot(logs: []);
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(_load());
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted && !_paused && PageActivityScope.isActiveOf(context)) {
          unawaited(_load());
        }
      });
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await RouterScope.read(context).backend.readLogs();
      if (!mounted) return;
      updateWhenRouteSettled(() {
        if (mounted) {
          setState(() {
            _snapshot = data;
            _list.setLogs(data.logs);
            _error = null;
          });
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loaded = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LogsState>(
    valueListenable: _list,
    builder: (context, state, _) {
      final logs = state.list.reversed.toList();
      return LogsPage(
        controller: _scroll,
        physics: _physics,
        count: logs.length,
        itemBuilder: (context, index) => LogRecordItem(
          log: LogRecord(
            dateTime: logs[index].dateTime,
            level: logs[index].logLevel.name,
            payload: logs[index].payload,
          ),
          onClick: (value) => context.commonScaffoldState?.addKeyword(value),
        ),
        timestampAt: (index) => logs[index].dateTime,
        searching: state.isSearching,
        following: state.autoScrollToEnd,
        loading: !_loaded,
        error: _error == null ? null : routerError(context, _error!),
        onSearch: _list.search,
        onKeywords: _list.updateKeywords,
        onPause: () => _list.setAutoScrollToEnd(false),
        onResume: () {
          _list.resumeAutoScrollToEnd(_snapshot.logs);
          unawaited(_load());
        },
        onExport: () => RouterScope.read(
          context,
        ).client.exportText('iping.log', _snapshot.source ?? ''),
      );
    },
  );

  @override
  void dispose() {
    _timer?.cancel();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class RouterFontFamily extends StatelessWidget {
  const RouterFontFamily({super.key});
  @override
  Widget build(BuildContext context) {
    final app = RouterAppState.of(context);
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.fontFamily,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, context.appBarInset, 16, 20),
        children: [
          generateSection(
            items: [
              for (final choice in <(String?, String)>[
                (null, l.defaultText),
                ('packages/fl_clash/JetBrainsMono', 'JetBrains Mono'),
              ])
                ListItem(
                  title: Text(choice.$2),
                  trailing: app.preferences.fontFamily == choice.$1
                      ? const GlyphIcon(AppGlyphs.check)
                      : null,
                  onTap: () => app.updatePreferences(
                    (value) => value.fontFamily = choice.$1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
