import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/l10n_labels.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/iping/script_form.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/views/profiles/extend/standard.dart';
import 'package:fl_clash/views/proxies/setting.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../helpers/context_menu.dart';
import '../helpers/app_paths.dart';
import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../plugins/code_forge/support.dart';

class _TestScripts extends Scripts {
  _TestScripts(this.initial);

  final List<Script> initial;
  final orders = <List<int>>[];

  @override
  Stream<List<Script>> build() => Stream.value(initial);

  @override
  Future<List<Script>> resourceSnapshot() async => state.value ?? initial;

  @override
  Future<void> orderResources(List<int> ids) async {
    orders.add(ids);
    final byId = {for (final item in state.value ?? initial) item.id: item};
    state = AsyncData([for (final id in ids) byId[id]!]);
  }
}

class _RecordingScriptsAction extends ScriptsAction {
  final updated = <Script>[];

  @override
  Future<void> updateScript(Script script) async {
    updated.add(script);
  }
}

class _TestGlobalRules extends GlobalRules {
  _TestGlobalRules(this.initial);

  final List<Rule> initial;

  @override
  Stream<List<Rule>> build() => Stream.value(initial);
}

class _TestProfileAddedRules extends ProfileRules {
  _TestProfileAddedRules(this.initial);

  final List<Rule> initial;

  @override
  Stream<List<Rule>> build(int profileId) => Stream.value(initial);

  @override
  void order(int oldIndex, int newIndex) {}
}

class _TestProfileDisabledRuleIds extends ProfileDisabledRuleIds {
  _TestProfileDisabledRuleIds(this.initial);

  final List<int> initial;

  @override
  Stream<List<int>> build(int profileId) => Stream.value(initial);
}

ProviderContainer _containerFor(
  WidgetTester tester, {
  List<Override> overrides = const [],
  List<Profile>? profiles,
  Size size = const Size(1400, 1000),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(
        profiles == null ? TestProfiles.new : () => TestProfiles(profiles),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  return container;
}

void main() {
  late Directory home;
  setUpAll(() async {
    home = Directory.systemTemp.createTempSync('flclash-shared-script-view-');
    await useAppPaths(home);
  });
  tearDownAll(() => home.deleteSync(recursive: true));

  testWidgets('proxies setting picks its style from a menu', (tester) async {
    final container = _containerFor(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: ProxiesSetting())),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;

    expect(find.text(l10n.iconStyle), findsOneWidget);

    await tester.tap(find.text(l10n.style));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProxiesType.tab.label));
    await tester.pumpAndSettle();

    expect(container.read(proxiesStyleSettingProvider).type, ProxiesType.tab);
    expect(find.text(l10n.iconStyle), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('proxies setting sorts by delay when selected', (tester) async {
    final container = _containerFor(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: ProxiesSetting())),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;

    await tester.tap(find.text(l10n.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delay));
    await tester.pumpAndSettle();

    expect(
      container.read(proxiesStyleSettingProvider).sortType,
      ProxiesSortType.delay,
    );
    expect(find.byType(CommonPopupMenu), findsNothing);
  });

  testWidgets('scripts view lists scripts and offers the add menu', (
    tester,
  ) async {
    final scripts = List.generate(
      4,
      (index) => Script(
        id: index + 1,
        label: 'Script $index',
        lastUpdateTime: DateTime(2026, 1, index + 1),
      ),
    );
    final container = _containerFor(
      tester,
      overrides: [scriptsProvider.overrideWith(() => _TestScripts(scripts))],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ScriptsView()),
      ),
    );
    await settle(tester);

    expect(find.byType(ScriptsView), findsOneWidget);
    expect(find.text('Script 0'), findsOneWidget);
    expect(find.text('Script 3'), findsOneWidget);
    expect(find.byGlyph(AppGlyphs.more), findsNothing);
    expect(find.text('Local'), findsNWidgets(4));
    expect(tester.takeException(), null);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Import from URL'), findsOneWidget);
    expect(find.text('Import from file'), findsOneWidget);
  });

  testWidgets('a new script asks before a name alone is discarded', (
    tester,
  ) async {
    await tester.runAsync(initEditorNative);
    final container = _containerFor(
      tester,
      overrides: [scriptsProvider.overrideWith(() => _TestScripts(const []))],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ScriptsView()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await settle(tester, 18);

    await tester.enterText(
      find.descendant(
        of: find.byType(IpingScriptForm),
        matching: find.byType(TextFormField),
      ),
      'Named',
    );
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester, 12);

    expect(find.text('Save the changes?'), findsOneWidget);
  });

  testWidgets('scripts view offers sync only for scripts with a source URL', (
    tester,
  ) async {
    const url = 'https://example.com/remote.js';
    final local = Script(
      id: 1,
      label: 'Local script',
      lastUpdateTime: DateTime(2026),
    );
    final remote = Script(
      id: 2,
      label: 'Remote script',
      lastUpdateTime: DateTime(2026),
      url: url,
    );
    final action = _RecordingScriptsAction();
    final container = _containerFor(
      tester,
      overrides: [
        scriptsProvider.overrideWith(() => _TestScripts([local, remote])),
        scriptsActionProvider.overrideWith(() => action),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ScriptsView()),
      ),
    );
    await settle(tester);

    expect(find.text(url), findsNothing);
    expect(find.byType(LastUpdateTimeText), findsNWidgets(2));
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);

    await rightClick(tester, find.text('Local script'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Sync'), findsNothing);
    expect(find.text('URL'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Remote script'));
    await tester.pumpAndSettle();
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);

    await tester.tap(find.text('Sync'));
    await settle(tester);

    expect(action.updated, [remote]);
  });

  testWidgets('scripts view reorders a script by its handle in sort mode', (
    tester,
  ) async {
    final scripts = List.generate(
      3,
      (index) => Script(
        id: index + 1,
        label: 'Script $index',
        lastUpdateTime: DateTime(2026),
      ),
    );
    final notifier = _TestScripts(scripts);
    final container = _containerFor(
      tester,
      overrides: [scriptsProvider.overrideWith(() => notifier)],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ScriptsView()),
      ),
    );
    await settle(tester);

    final to = tester.getCenter(find.text('Script 2'));
    final pressed = await tester.startGesture(
      tester.getCenter(find.text('Script 0')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await pressed.moveTo(to + const Offset(0, 100));
    await settle(tester);
    await pressed.up();
    await tester.pumpAndSettle();
    expect(notifier.orders, isEmpty);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SortHandle).first),
    );
    await tester.pump(kPressTimeout);
    await gesture.moveTo(
      Offset(tester.getCenter(find.byType(SortHandle).first).dx, to.dy + 100),
    );
    await settle(tester);
    await gesture.up();
    await settle(tester, 20);
    await tester.pumpAndSettle();

    expect(notifier.orders, [
      [2, 3, 1],
    ]);
  });

  testWidgets('scripts view renders an empty state without scripts', (
    tester,
  ) async {
    final container = _containerFor(
      tester,
      overrides: [scriptsProvider.overrideWith(() => _TestScripts(const []))],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ScriptsView()),
      ),
    );
    await tester.pump();

    expect(find.byType(ScriptsView), findsOneWidget);
    expect(find.text('Script 0'), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('standard extension renders added rules and selection state', (
    tester,
  ) async {
    final profile = Profile.normal();
    final addedRules = List.generate(
      6,
      (index) => Rule(
        id: 300 + index,
        content: 'added$index.com',
        ruleTarget: 'DIRECT',
        order: index.toString(),
      ),
    );
    final globalRules = List.generate(
      3,
      (index) => Rule(
        id: 400 + index,
        content: 'global$index.com',
        ruleTarget: 'DIRECT',
        order: index.toString(),
      ),
    );
    final container = _containerFor(
      tester,
      profiles: [profile],
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profileRulesProvider.overrideWith2(
          (_) => _TestProfileAddedRules(addedRules),
        ),
        globalRulesProvider.overrideWith(() => _TestGlobalRules(globalRules)),
        profileDisabledRuleIdsProvider.overrideWith2(
          (_) => _TestProfileDisabledRuleIds(const []),
        ),
        clashConfigProvider(
          profile.id,
        ).overrideWithValue(const AsyncData(ClashConfig())),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: ProfileIdProvider(
            profileId: profile.id,
            child: const Scaffold(
              body: CustomScrollView(slivers: [StandardContent()]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StandardContent), findsOneWidget);
    expect(find.text('added0.com'), findsOneWidget);
    expect(tester.takeException(), null);

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      for (var index = 0; index < 4; index++) {
        await tester.drag(scrollables.first, const Offset(0, -400));
        await tester.pump();
      }
    }
    expect(tester.takeException(), null);
  });

  testWidgets('standard extension picks a MATCH-TARGET from the profile', (
    tester,
  ) async {
    final profile = Profile.normal();
    final container = _containerFor(
      tester,
      profiles: [profile],
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profileRulesProvider.overrideWith2(
          (_) => _TestProfileAddedRules(const []),
        ),
        globalRulesProvider.overrideWith(() => _TestGlobalRules(const [])),
        profileDisabledRuleIdsProvider.overrideWith2(
          (_) => _TestProfileDisabledRuleIds(const []),
        ),
        clashConfigProvider(profile.id).overrideWithValue(
          const AsyncData(
            ClashConfig(
              proxies: [Proxy(name: 'HK', type: 'ss')],
              proxyGroups: [
                ProxyGroup(id: 1, name: 'Proxy', type: GroupType.Selector),
              ],
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: ProfileIdProvider(
            profileId: profile.id,
            child: const Scaffold(
              body: CustomScrollView(slivers: [StandardContent()]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;
    expect(find.text(l10n.followProfile), findsOneWidget);

    await tester.tap(find.text(l10n.matchTarget));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionSheet<String>), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);

    await tester.tap(find.text('HK'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionSheet<String>), findsNothing);
    expect(container.read(profilesProvider).first.matchTarget, 'HK');
    expect(find.text('HK'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('the global added rules page opens where they are added in a '
      'sheet over itself', (tester) async {
    final profile = Profile.normal();
    final container = _containerFor(
      tester,
      profiles: [profile],
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profileRulesProvider.overrideWith2(
          (_) => _TestProfileAddedRules(const []),
        ),
        globalRulesProvider.overrideWith(() => _TestGlobalRules(const [])),
        profileDisabledRuleIdsProvider.overrideWith2(
          (_) => _TestProfileDisabledRuleIds(const []),
        ),
        clashConfigProvider(
          profile.id,
        ).overrideWithValue(const AsyncData(ClashConfig())),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: ProfileIdProvider(
            profileId: profile.id,
            child: const Scaffold(
              body: CustomScrollView(slivers: [StandardContent()]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;

    await tester.tap(find.text(l10n.controlGlobalAddedRules));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.goToConfigureAddedRules));
    await tester.pumpAndSettle();

    expect(find.byType(AddedRulesView), findsOneWidget);
    expect(find.text(l10n.editGlobalRules), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
