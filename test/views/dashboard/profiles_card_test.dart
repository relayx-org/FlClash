import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/iping/subscription.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_detail.dart';
import 'package:fl_clash/views/dashboard/widgets/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../helpers/app_paths.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

const _gib = 1024 * 1024 * 1024;

ExternalProvider _provider(String name, String type, int count) =>
    ExternalProvider(
      name: name,
      type: type,
      count: count,
      vehicleType: 'HTTP',
      updateAt: DateTime(2026),
    );

Profile _profile(
  int id, {
  SubscriptionInfo? info,
  ProfileType type = ProfileType.file,
}) => Profile(
  id: id,
  label: 'P$id',
  type: type,
  url: 'https://sub$id.example.com/link',
  autoUpdateDuration: Duration.zero,
  lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
  subscriptionInfo: info,
);

void main() {
  late ProviderContainer container;

  setUpAll(() async {
    final home = Directory.systemTemp.createTempSync('profiles_card');
    addTearDown(() => home.deleteSync(recursive: true));
    await useAppPaths(home);
  });

  void setUpProfiles(
    List<Profile> profiles, {
    List<Override> overrides = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 1000)),
        ...overrides,
      ],
    );
    globalState.container = container;
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value =
        profiles.firstOrNull?.id;
    addTearDown(container.dispose);
  }

  /// The counts are parsed in an isolate, which only runs in real time;
  /// without [until] this waits for the card to stop loading them.
  Future<void> settleCounts(WidgetTester tester, {Finder? until}) async {
    bool done() => until != null
        ? until.evaluate().isNotEmpty
        : find.byType(SkeletonText).evaluate().isEmpty;
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    Widget card = const ProfilesCard(),
    double width = 360,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: card),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await settleCounts(tester);
  }

  Future<void> pumpDesktopCard(WidgetTester tester) => pumpCard(
    tester,
    card: const DashboardDensityScope(
      density: DashboardDensity.standard,
      scale: 1,
      child: SizedBox(height: 176, child: ProfilesCard()),
    ),
    width: 300,
  );

  Finder label(String text) => find.text(text, findRichText: true);

  testWidgets('offers subscription details without profiles', (tester) async {
    setUpProfiles([]);
    await pumpCard(tester);

    expect(find.text('Subscription info'), findsOneWidget);

    await pumpDesktopCard(tester);
    expect(find.text('Subscription info'), findsOneWidget);
    expect(find.byTooltip('Switch profile'), findsNothing);
  });

  testWidgets('shows the current profile, its usage and when it ends', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
      _profile(2),
    ]);
    await pumpCard(tester);

    expect(label('P1'), findsOneWidget);
    expect(label('P2'), findsNothing);
    expect(find.textContaining('42%', findRichText: true), findsOneWidget);
    expect(find.text('42 GB / 100 GB'), findsOneWidget);
    expect(find.textContaining('30 days left'), findsOneWidget);
  });

  testWidgets('the desktop card puts the days left beside its update time', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    ]);
    await pumpDesktopCard(tester);

    expect(label('P1'), findsOneWidget);
    expect(find.text('30 days left'), findsOneWidget);
    expect(find.textContaining('42%', findRichText: true), findsOneWidget);
    expect(find.text('42 GB / 100 GB'), findsOneWidget);
    expect(find.byTooltip('Update'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a desktop card without a quota names where the profile is '
      'from', (tester) async {
    setUpProfiles([_profile(1)]);
    await pumpDesktopCard(tester);

    expect(find.text('Local'), findsOneWidget);
    expect(find.textContaining('%', findRichText: true), findsNothing);
    expect(find.byTooltip('Update'), findsNothing);
    expect(find.byTooltip('Switch profile'), findsNothing);
  });

  testWidgets('does not expose profile import or switching', (tester) async {
    setUpProfiles([_profile(1), _profile(2)]);
    await pumpDesktopCard(tester);
    expect(find.byTooltip('Switch profile'), findsNothing);
    expect(find.text('Add profile'), findsNothing);
  });

  Future<File> writeAppliedConfig(WidgetTester tester) async {
    final file = await tester.runAsync(() async {
      final file = File(await appPath.configFilePath);
      await file.writeAsString(
        'proxies:\n'
        '  - {name: a, type: ss}\n'
        '  - {name: b, type: ss}\n'
        'proxy-groups:\n'
        '  - {name: g, type: select, proxies: [a]}\n'
        'rules:\n'
        '  - MATCH,DIRECT\n'
        '  - DOMAIN,a.com,DIRECT\n'
        '  - GEOIP,CN,DIRECT\n',
      );
      return file;
    });
    addTearDown(() async {
      if (file!.existsSync()) file.deleteSync();
    });
    return file!;
  }

  testWidgets('tapping the subscription opens its details without navigation', (
    tester,
  ) async {
    setUpProfiles([_profile(1)]);
    container.listen(currentPageLabelProvider, (_, _) {});
    await pumpCard(tester);
    await tester.tap(label('P1'));
    await tester.pumpAndSettle();
    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    expect(find.byType(IpingSubscriptionDetails), findsOneWidget);
    expect(find.byType(ProfileDetailSheet), findsNothing);
  });

  testWidgets('counts recorded at the last apply skip the config file', (
    tester,
  ) async {
    final config = await writeAppliedConfig(tester);
    await tester.runAsync(
      () => config.writeAsBytes(List.filled((8 << 20) + 1, 0x20)),
    );
    setUpProfiles([_profile(1)]);
    await pumpDesktopCard(tester);
    expect(find.byType(SkeletonText), findsNothing);
    expect(find.text('—'), findsNWidgets(3));

    globalState.lastConfigCounts = (groups: 4, proxies: 2048, rules: 9);
    addTearDown(() => globalState.lastConfigCounts = null);
    container.read(groupsProvider.notifier).value = [
      const Group(type: GroupType.Selector, name: 'G1'),
    ];
    await tester.pump();

    expect(find.text(dashboardCount(2048)), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.byType(SkeletonText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card without a quota counts what its config holds', (
    tester,
  ) async {
    await writeAppliedConfig(tester);
    setUpProfiles(
      [_profile(1)],
      overrides: [
        providersProvider.overrideWithBuild(
          (_, _) => [_provider('nodes', 'Proxy', 5)],
        ),
      ],
    );
    await pumpDesktopCard(tester);
    await settleCounts(tester, until: find.text('3'));

    for (final (title, value) in [
      ('Proxy group', '1'),
      ('Proxies', '7'),
      ('Rules', '3'),
    ]) {
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Column))
              .first,
          matching: find.text(value),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow card drops words before it cuts the time or traffic', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    ]);
    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.standard,
        scale: 1,
        child: SizedBox(height: 176, child: ProfilesCard()),
      ),
      width: 600,
    );
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(find.textContaining('used', findRichText: true), findsOneWidget);

    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.standard,
        scale: 1,
        child: SizedBox(height: 176, child: ProfilesCard()),
      ),
      width: 240,
    );
    expect(find.textContaining('Updated'), findsNothing);
    expect(find.textContaining('minutes ago'), findsOneWidget);
    expect(find.textContaining('used', findRichText: true), findsNothing);
    expect(find.text('42 GB / 100 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact card puts the days left beside the name and leaves '
      'the update time to the details', (tester) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
      _profile(2),
    ]);
    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.compact,
        scale: 1,
        child: SizedBox(height: 152, child: ProfilesCard()),
      ),
      width: 220,
    );

    final name = tester.getRect(label('P1'));
    final daysLeft = tester.getRect(find.text('30 days left'));
    expect(daysLeft.center.dy, moreOrLessEquals(name.center.dy, epsilon: 1));
    expect(find.byTooltip('Switch profile'), findsNothing);
    expect(find.textContaining('minutes ago'), findsNothing);
    expect(find.text('42 GB / 100 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('counts provider proxies but not provider rules', () {
    final stats = profileStatsOf(
      configCountsOf({
        'proxies': [{}],
        'proxy-groups': [{}, {}],
        'rules': ['MATCH,DIRECT'],
      }),
      [_provider('nodes', 'Proxy', 4), _provider('ads', 'Rule', 900)],
    );

    expect(stats, (groups: 2, proxies: 5, rules: 1, providers: 2));
  });
}
