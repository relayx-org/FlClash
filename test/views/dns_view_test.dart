import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/config_value.dart';
import 'package:fl_clash/iping/core_settings_page.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _profileId = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pumpView(WidgetTester tester, {bool profile = false}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(
              id: _profileId,
              type: ProfileType.custom,
              autoUpdateDuration: Duration.zero,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1200, 1000));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: profile ? const DnsView.profile(_profileId) : const DnsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PatchClashConfig config() => container.read(patchClashConfigProvider);

  ProfileOverrides overrides() =>
      container.read(profilesProvider).getProfile(_profileId)!.overrides;

  void setProfileKeys(Set<DnsOverrideKey> keys) {
    container
        .read(profilesProvider.notifier)
        .updateProfile(
          _profileId,
          (profile) => profile.copyWith.overrides(dnsOverrideKeys: keys),
        );
  }

  Finder inSheet(String title) => find.descendant(
    of: find.byType(SelectionSheet<DnsOverrideKey>),
    matching: find.text(title),
  );

  Future<void> openAddSheet(WidgetTester tester, {bool profile = false}) async {
    final l = currentAppLocalizations;
    await tester.tap(
      find.text(profile ? l.addSettingEntry : l.addOverrideEntry),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the app-wide DNS page uses the shared editor and supported keys',
    (tester) async {
      await pumpView(tester);
      expect(find.byType(IpingCoreSettingsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('dns.ipv6')), findsOneWidget);
      expect(find.byKey(const ValueKey('dns.enable')), findsNothing);
      expect(find.byKey(const ValueKey('dns.nameserver-policy')), findsNothing);
      final row = tester.widget<ConfigToggleValue>(
        find.byKey(const ValueKey('dns.ipv6')),
      );
      row.onChanged!(!defaultDns.ipv6);
      await tester.pumpAndSettle();
      expect(config().dnsOverrideKeys, contains(DnsOverrideKey.ipv6));
      expect(config().dns.ipv6, !defaultDns.ipv6);
    },
  );

  testWidgets(
    'an empty nameserver override stays explicit and reset follows the profile',
    (tester) async {
      await pumpView(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('dns.nameserver')));
      await tester.tap(find.byKey(const ValueKey('dns.nameserver')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(ListEditView))).pop(<String>[]);
      await tester.pumpAndSettle();
      expect(config().dnsOverrideKeys, contains(DnsOverrideKey.nameserver));
      expect(config().dns.nameserver, isEmpty);
      final menu = tester.widget<ContextMenuRegion>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('dns.nameserver')),
              matching: find.byType(ContextMenuRegion),
            )
            .first,
      );
      menu.menuItems!.single.onPressed!();
      await tester.pumpAndSettle();
      expect(
        config().dnsOverrideKeys,
        isNot(contains(DnsOverrideKey.nameserver)),
      );
      expect(config().dns.nameserver, defaultDns.nameserver);
    },
  );

  Future<EditorPage> openQuickEdit(WidgetTester tester) async {
    await tester.tap(find.byTooltip(currentAppLocalizations.quickEdit));
    await tester.pumpAndSettle();
    return tester.widget<EditorPage>(find.byType(EditorPage));
  }

  group('a custom profile', () {
    testWidgets('keeps its keys apart from the app-wide ones', (tester) async {
      await pumpView(tester, profile: true);

      await openAddSheet(tester, profile: true);
      await tester.tap(find.text(currentAppLocalizations.respectRules));
      await tester.pumpAndSettle();

      expect(overrides().dnsOverrideKeys, {DnsOverrideKey.respectRules});
      expect(overrides().dns.respectRules, defaultDns.respectRules);
      expect(config().dnsOverrideKeys, isEmpty);
    });

    testWidgets('describes its own settings rather than overrides', (
      tester,
    ) async {
      final l = currentAppLocalizations;
      await pumpView(tester, profile: true);

      expect(find.text(l.nullTip(l.settingEntries)), findsOneWidget);
      expect(find.text(l.profileSettingsDesc), findsOneWidget);
      expect(find.text(l.dnsOverrideDesc), findsNothing);

      await openAddSheet(tester, profile: true);
      expect(inSheet(l.addSettingEntry), findsOneWidget);
    });

    testWidgets('groups entries by what they configure', (tester) async {
      await pumpView(tester, profile: true);
      setProfileKeys({
        DnsOverrideKey.fallbackFilterDomain,
        DnsOverrideKey.nameserver,
        DnsOverrideKey.fakeIpTtl,
        DnsOverrideKey.enable,
      });
      await tester.pump();

      final l = currentAppLocalizations;
      double header(String title) =>
          tester.getTopLeft(find.widgetWithText(ListHeader, title)).dy;
      final headers = [
        l.options,
        'Fake-IP',
        'Nameserver',
        l.fallbackFilter,
      ].map(header).toList();
      for (var i = 1; i < headers.length; i++) {
        expect(headers[i - 1], lessThan(headers[i]));
      }
      final ttl = tester.getTopLeft(find.text(l.fakeipTtl)).dy;
      expect(ttl, inExclusiveRange(headers[1], headers[2]));
      expect(
        tester.getTopLeft(find.text(l.domain)).dy,
        greaterThan(headers[3]),
      );
    });

    testWidgets('a list entry closed unchanged stays and one emptied is '
        'taken off', (tester) async {
      await pumpView(tester, profile: true);
      setProfileKeys({DnsOverrideKey.nameserver, DnsOverrideKey.fallback});
      container
          .read(profilesProvider.notifier)
          .updateProfile(
            _profileId,
            (profile) => profile.copyWith.overrides.dns(
              nameserver: ['1.1.1.1'],
              fallback: [],
            ),
          );
      await tester.pump();

      await tester.tap(find.text('Fallback'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(overrides().dnsOverrideKeys, contains(DnsOverrideKey.fallback));

      final nameserver = find.ancestor(
        of: find.text('Nameserver'),
        matching: find.byType(ConfigListEditItem),
      );
      tester
          .widget<ConfigListEditItem>(nameserver)
          .onChanged(tester.element(nameserver) as WidgetRef, const []);
      await tester.pumpAndSettle();
      expect(overrides().dnsOverrideKeys, {DnsOverrideKey.fallback});
      expect(overrides().dns.nameserver, defaultDns.nameserver);
    });

    testWidgets('a policy entry summarises its rules', (tester) async {
      await pumpView(tester, profile: true);
      setProfileKeys({
        DnsOverrideKey.nameserverPolicy,
        DnsOverrideKey.proxyServerNameserverPolicy,
      });
      container
          .read(profilesProvider.notifier)
          .updateProfile(
            _profileId,
            (profile) => profile.copyWith.overrides.dns(
              nameserverPolicy: {'+.example.com': '1.1.1.1'},
            ),
          );
      await tester.pump();

      expect(find.text(currentAppLocalizations.itemsCount(1)), findsOneWidget);
      expect(find.text(currentAppLocalizations.none), findsOneWidget);
    });

    testWidgets('a number entry writes the integer it is given', (
      tester,
    ) async {
      await pumpView(tester, profile: true);
      setProfileKeys({DnsOverrideKey.ipv6Timeout});
      await tester.pump();

      await tester.tap(find.text(currentAppLocalizations.ipv6Timeout));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '300');
      await tester.tap(find.text(currentAppLocalizations.submit));
      await tester.pumpAndSettle();

      expect(overrides().dns.ipv6Timeout, 300);
      expect(find.text('300'), findsOneWidget);
    });

    testWidgets('quick edit opens its section and applies it on exit', (
      tester,
    ) async {
      await pumpView(tester, profile: true);
      setProfileKeys({DnsOverrideKey.ipv6});
      await tester.pump();

      final editor = await openQuickEdit(tester);
      expect(editor.content, contains('ipv6: false'));
      expect(editor.readOnly, isFalse);
      expect(editor.onSave, isNull);

      final context = tester.element(find.byType(EditorPage));
      final popped = await editor.onPop!(context, 'DNS', 'listen: :53');
      expect(popped, isTrue);
      expect(overrides().dnsOverrideKeys, {DnsOverrideKey.listen});
      expect(overrides().dns.listen, ':53');
    });

    testWidgets('a quick edit naming an unknown key is refused', (
      tester,
    ) async {
      await pumpView(tester, profile: true);
      final editor = await openQuickEdit(tester);
      final context = tester.element(find.byType(EditorPage));

      final popped = editor.onPop!(context, 'DNS', 'bogus: 1');
      await tester.pump();
      expect(
        find.textContaining(currentAppLocalizations.discardChanges),
        findsOneWidget,
      );
      await tester.tap(find.text(currentAppLocalizations.cancel));
      await tester.pump();
      expect(await popped, isFalse);
      expect(overrides().dnsOverrideKeys, isEmpty);
    });

    testWidgets('a policy picked from the sheet starts empty', (tester) async {
      await pumpView(tester, profile: true);

      await openAddSheet(tester, profile: true);
      await tester.drag(
        inSheet(currentAppLocalizations.addSettingEntry),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Nameserver Policy'),
        find.byType(SelectionSheet<DnsOverrideKey>),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nameserver Policy'));
      await tester.pumpAndSettle();

      expect(overrides().dnsOverrideKeys, {DnsOverrideKey.nameserverPolicy});
      expect(overrides().dns.nameserverPolicy, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SelectionSheet<DnsOverrideKey>), findsNothing);
      await tester.tap(find.text('Nameserver Policy'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(overrides().dnsOverrideKeys, {DnsOverrideKey.nameserverPolicy});
    });
  });
}
