import 'package:fl_clash/iping/profile_resources_page.dart';
import 'package:fl_clash/iping/script_form.dart';
import 'package:fl_clash/features/form/rule_form.dart';
import 'package:fl_clash/features/form/selection_sheet_view.dart';
import 'package:fl_clash/views/config/custom_resources_page.dart';
import 'package:fl_clash/features/form/custom_proxy_editor.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/iping/rule_provider_form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/iping/filters_page.dart';
import 'package:fl_clash/ui/config_value.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/config/general_page.dart';
import 'package:fl_clash/views/config/port_form.dart';
import 'package:fl_clash/views/settings_page.dart';
import 'package:fl_clash/widgets/appearance_controls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iping_openwrt/app.dart';
import 'package:iping_openwrt/controller.dart';
import 'package:iping_openwrt/preferences.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_client.dart';

Future<void> _openSettings(WidgetTester tester, FakeRouterClient client) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _Assets(),
      child: RouterApp(client: client),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationSidebar),
      matching: find.text(AppLocalizations.current.settings),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'resource application keeps selections on failure and applies only after saving',
    (tester) async {
      final client = FakeRouterClient();
      client.settings['custom.proxies'] = [
        {
          'id': 'home',
          'definition': {'name': 'Home', 'type': 'direct'},
          'emptyOptions': <String>[],
        },
      ];
      await _openSettings(tester, client);
      final l = AppLocalizations.current;
      await tester.tap(find.text(l.customProfileResources));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.applyResources));
      await tester.pumpAndSettle();
      expect(find.byType(IpingProfileResourcesPage), findsOneWidget);
      await tester.tap(find.text('Home'));
      client.failSettings = true;
      await tester.tap(find.byTooltip(l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.routerOperationFailed), findsOneWidget);
      expect((client.settings['custom.bindings'] as Map)['proxies'], isEmpty);
      client.failSettings = false;
      await tester.tap(find.byTooltip(l.save));
      await tester.pumpAndSettle();
      expect((client.settings['custom.bindings'] as Map)['proxies'], ['home']);
      expect(find.byType(IpingProfileResourcesPage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('scripts share their editor and retain a failed draft', (
    tester,
  ) async {
    final client = FakeRouterClient();
    await _openSettings(tester, client);
    final l = AppLocalizations.current;
    await tester.tap(find.text(l.advancedConfig));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.script));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.add));
    await tester.pumpAndSettle();
    expect(find.byType(IpingScriptForm), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Transform');
    client.failSettings = true;
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.byType(IpingScriptForm), findsOneWidget);
    expect(client.settings['custom.scripts'], isEmpty);
    client.failSettings = false;
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.byType(IpingScriptForm), findsNothing);
    expect(
      (client.settings['custom.scripts'] as List).single,
      containsPair('label', 'Transform'),
    );
    expect((client.settings['custom.bindings'] as Map)['script'], isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('rules use the shared structured editor', (tester) async {
    final client = FakeRouterClient();
    await _openSettings(tester, client);
    final l = AppLocalizations.current;
    await tester.tap(find.text(l.advancedConfig));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.addedRules));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.add));
    await tester.pumpAndSettle();
    expect(find.byType(RuleForm), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'example.com');
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.byType(RuleForm), findsNothing);
    expect(
      ((client.settings['custom.rules'] as List).single as Map)['definition'],
      containsPair('content', 'example.com'),
    );
    expect((client.settings['custom.bindings'] as Map)['rules'], isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'custom nodes use the shared structured editor and preserve failed saves',
    (tester) async {
      final client = FakeRouterClient();
      await _openSettings(tester, client);
      final l = AppLocalizations.current;
      await tester.tap(find.text(l.customProfileResources));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CustomResourcesSettingsPage),
          matching: find.text(l.proxies),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.add));
      await tester.pumpAndSettle();
      expect(find.byType(IpingCustomProxyEditor), findsOneWidget);
      Finder field(String title) => find.descendant(
        of: find
            .ancestor(of: find.text(title), matching: find.byType(FormRow))
            .first,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field(l.name), 'Home');
      await tester.enterText(field(l.server), 'proxy.example.com');
      await tester.enterText(field(l.port), '8388');
      await tester.enterText(field(l.password), 'fixture-secret');
      await tester.ensureVisible(find.text(l.addSettingEntry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.addSettingEntry));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is SelectionSheetView),
          matching: find.text(l.interfaceName),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      client.failSettings = true;
      await tester.tap(find.widgetWithText(TextButton, l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.routerOperationFailed), findsOneWidget);
      expect(find.byType(IpingCustomProxyEditor), findsOneWidget);
      expect(client.settings['custom.proxies'], isEmpty);
      client.failSettings = false;
      await tester.tap(find.widgetWithText(TextButton, l.save));
      await tester.pumpAndSettle();
      expect(find.byType(IpingCustomProxyEditor), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      final proxy = (client.settings['custom.proxies']! as List).single as Map;
      expect(proxy['id'], isA<String>());
      expect(proxy['definition'], containsPair('server', 'proxy.example.com'));
      expect(proxy['definition'], containsPair('password', 'fixture-secret'));
      expect(proxy['emptyOptions'], contains('interfaceName'));
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text(l.interfaceName), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'rule providers share the options form and retain rejected drafts',
    (tester) async {
      final client = FakeRouterClient();
      await _openSettings(tester, client);
      final l = AppLocalizations.current;
      await tester.tap(find.text(l.customProfileResources));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.ruleProviders));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.add));
      await tester.pumpAndSettle();
      expect(find.byType(IpingRuleProviderForm), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(FormPage),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Ads');
      await tester.enterText(fields.at(1), 'file:///etc/shadow');
      await tester.tap(find.widgetWithText(TextButton, l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.providerUrlTip), findsOneWidget);
      expect(client.settings['custom.rule-providers'], isEmpty);
      await tester.enterText(fields.at(1), 'https://example.com/ads.yaml');
      client.failSettings = true;
      await tester.tap(find.widgetWithText(TextButton, l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.routerOperationFailed), findsOneWidget);
      expect(tester.widget<FormPage>(find.byType(FormPage)).saving, isFalse);
      client.failSettings = false;
      await tester.tap(find.widgetWithText(TextButton, l.save));
      await tester.pumpAndSettle();
      expect(find.byType(FormPage), findsNothing);
      expect(find.text('Ads'), findsOneWidget);
      expect(
        ((client.settings['custom.rule-providers']! as List).single
            as Map)['url'],
        'https://example.com/ads.yaml',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('resource filters share the native form and keep failed edits', (
    tester,
  ) async {
    final client = FakeRouterClient();
    await _openSettings(tester, client);
    final l = AppLocalizations.current;
    await tester.tap(find.text(l.customProfileResources));
    await tester.pumpAndSettle();
    expect(find.text(l.groupIcons), findsOneWidget);
    expect(find.text(l.iconSets), findsNothing);
    await tester.tap(find.text(l.filters));
    await tester.pumpAndSettle();
    expect(find.byType(IpingFiltersPage), findsOneWidget);
    await tester.tap(find.byTooltip(l.add));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(FormPage),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Asia');
    await tester.enterText(fields.at(1), '(broken');
    client.filterErrors['(broken'] = 'missing closing )';
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.text('missing closing )'), findsOneWidget);
    expect(client.settings['custom.filters'], isEmpty);
    await tester.enterText(fields.at(1), r'(?<=hk)1`jp');
    client.failSettings = true;
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.text(l.routerOperationFailed), findsOneWidget);
    expect(tester.widget<FormPage>(find.byType(FormPage)).saving, isFalse);
    expect(client.settings['custom.filters'], isEmpty);
    client.failSettings = false;
    await tester.tap(find.widgetWithText(TextButton, l.save));
    await tester.pumpAndSettle();
    expect(find.byType(FormPage), findsNothing);
    expect(find.text('Asia'), findsOneWidget);
    expect(client.settings['custom.filters'], [
      {'label': 'Asia', 'regex': r'(?<=hk)1`jp'},
    ]);
    await tester.tap(find.byType(CommonCheckBox));
    await tester.pumpAndSettle();
    client.failSettings = true;
    await tester.tap(find.byTooltip(l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();
    expect(find.text('Asia'), findsOneWidget);
    expect(
      tester.widget<CommonCheckBox>(find.byType(CommonCheckBox)).value,
      isTrue,
    );
    expect(find.text(l.routerOperationFailed), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'settings exposes shared general, advanced, resources and appearance pages',
    (tester) async {
      final client = FakeRouterClient();
      await _openSettings(tester, client);
      final l = AppLocalizations.current;
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text(l.general), findsOneWidget);
      expect(find.text(l.advancedConfig), findsOneWidget);
      expect(find.text(l.customProfileResources), findsOneWidget);
      await tester.tap(find.text(l.theme));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceSettingsPage), findsOneWidget);
      final appearance = tester.widget<AppearanceSettingsPage>(
        find.byType(AppearanceSettingsPage),
      );
      expect(appearance.primaryColor, isA<AppearancePaletteControl>());
      expect(appearance.textScale, isA<TextScaleControl>());
      expect(appearance.navigationBar, isA<NavigationBarChoice>());
      expect(appearance.tabAnimationControl, isA<TabAnimationChoice>());
      expect(appearance.pureBlack, isA<PureBlackChoice>());
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'general edits wait for the router and keep the old value on failure',
    (tester) async {
      final client = FakeRouterClient();
      await _openSettings(tester, client);
      await tester.tap(find.text(AppLocalizations.current.general));
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.byType(GeneralSettingsPage), findsOneWidget);
      final row = find.byKey(const ValueKey('allow-lan'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(client.settings['allow-lan'], isFalse);
      expect(
        client.requests
            .where((request) => request.$1 == 'settings_set')
            .single
            .$2['changes'],
        {'allow-lan': false},
      );
      expect(tester.widget<ConfigToggleValue>(row).value, isFalse);
      client.failSettings = true;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.widget<ConfigToggleValue>(row).value, isFalse);
      expect(
        find.text(AppLocalizations.current.routerOperationFailed),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'web ports use the native form and preserve router redirect defaults',
    (tester) async {
      final client = FakeRouterClient();
      await _openSettings(tester, client);
      await tester.tap(find.text(AppLocalizations.current.general));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.port));
      await tester.pumpAndSettle();
      expect(find.byType(PortSettingsForm), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, '7900');
      await tester.tap(
        find.widgetWithText(TextButton, AppLocalizations.current.save),
      );
      await tester.pumpAndSettle();
      expect(client.settings['mixed-port'], 7900);
      expect(client.settings['redir-port'], 7891);
      expect(client.settings['tproxy-port'], 7892);
      expect(find.byType(PortSettingsForm), findsNothing);
      expect(find.byType(GeneralSettingsPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('saved appearance and node preferences survive a fresh instance', () {
    final preferences = RouterPreferences()
      ..themeMode = ThemeMode.dark
      ..primaryColor = 0xff123456
      ..primaryColors = [0xff123456]
      ..pureBlack = true
      ..floatingBar = false
      ..customTextScale = true
      ..textScale = 1.3
      ..fontFamily = 'packages/fl_clash/JetBrainsMono'
      ..testUrl = 'https://example.com/test'
      ..openLogs = true
      ..closeConnections = false;
    final restored = RouterPreferences.fromJson(preferences.toJson());
    expect(restored.toJson(), preferences.toJson());
    expect(
      RouterPreferences.fromJson({
        'textScale': 100,
        'primaryColors': ['invalid'],
        'testUrl': 'file:///tmp',
      }).textScale,
      1.4,
    );
  });

  test(
    'settings job errors release busy state and propagate to the form',
    () async {
      final client = FakeRouterClient();
      final controller = RouterController(client);
      addTearDown(controller.dispose);
      await controller.initialize();
      client.jobError = 'service_failed';
      await expectLater(
        controller.saveSettings({'ipv6': true}),
        throwsA(isA<Object>()),
      );
      expect(controller.busy, isFalse);
      expect(client.settings['ipv6'], isFalse);
      client.jobError = null;
      await controller.saveSettings({'ipv6': true});
      expect(client.settings['ipv6'], isTrue);
      await controller.testDelay('Node A', url: 'https://example.com/test');
      expect(client.requests.last.$2['url'], 'https://example.com/test');
    },
  );

  testWidgets('DNS context menu restores just one field to the profile', (
    tester,
  ) async {
    final client = FakeRouterClient();
    client.settings['dns.use-hosts'] = false;
    client.settingOverrides['dns.use-hosts'] = true;
    client.settingOverrides['dns.nameserver'] = true;
    await _openSettings(tester, client);
    await tester.tap(find.text(AppLocalizations.current.advancedConfig));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DNS'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('dns.use-hosts'));
    expect(tester.widget<ConfigToggleValue>(row).value, isFalse);
    client.failSettings = true;
    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.followProfile));
    await tester.pumpAndSettle();
    expect(client.settingOverrides['dns.use-hosts'], isTrue);
    expect(tester.widget<ConfigToggleValue>(row).value, isFalse);
    expect(
      find.text(AppLocalizations.current.routerOperationFailed),
      findsWidgets,
    );
    client.failSettings = false;
    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.followProfile));
    await tester.pumpAndSettle();
    expect(client.settingOverrides['dns.use-hosts'], isFalse);
    expect(client.settingOverrides['dns.nameserver'], isTrue);
    expect(tester.widget<ConfigToggleValue>(row).value, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/fl_clash/$key' : key,
  );
}
