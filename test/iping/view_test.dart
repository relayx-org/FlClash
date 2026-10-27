import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/iping/api.dart';
import 'package:flutter/services.dart';
import 'package:fl_clash/iping/account.dart';
import 'package:fl_clash/iping/about.dart';
import 'package:fl_clash/iping/brand.dart';
import 'package:fl_clash/iping/browser.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:fl_clash/iping/session.dart';
import 'package:fl_clash/iping/subscription.dart';
import 'package:fl_clash/iping/view.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/icon.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'fakes.dart';

class _Browser extends IpingBrowserLogin {
  _Browser(this.apiFake)
    : super(
        site: apiFake.site,
        exchange: ({required code, required verifier}) =>
            throw UnimplementedError(),
      );
  final FakeIpingApi apiFake;
  Completer<IpingAccount?>? pending;
  bool? registered;
  @override
  Future<IpingAccount?> signIn({bool register = false}) {
    registered = register;
    return pending?.future ?? apiFake.authenticate();
  }

  @override
  void cancel() {
    final completion = pending;
    if (completion != null && !completion.isCompleted) {
      completion.complete(null);
    }
  }
}

void main() {
  late FakeIpingApi api;
  late _Browser browser;
  late MemorySessionStorage storage;
  late MemoryProfileStorage profiles;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeIpingApi();
    browser = _Browser(api);
    storage = MemorySessionStorage();
    profiles = MemoryProfileStorage();
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingAuthenticatedApiProvider.overrideWithValue(api),
        ipingBrowserProvider.overrideWithValue(browser),
        ipingStorageProvider.overrideWithValue(storage),
        ipingProfilesProvider.overrideWithValue(profiles),
        initProvider.overrideWithBuild((_, _) => true),
        profilesProvider.overrideWith(TestProfiles.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    ThemeData? theme,
    Locale? locale,
  }) async {
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(theme: theme, locale: locale, child: view),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'login offers all website methods without native credential inputs',
    (tester) async {
      await pump(tester, const IpingLoginView());
      expect(find.text('Sign in with browser'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.textContaining('Google'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
    },
  );

  testWidgets(
    'manual import validates links and opens home without signing in',
    (tester) async {
      await pump(tester, const IpingGate(child: Text('HOME')));
      await tester.ensureVisible(
        find.text('Import a subscription without signing in'),
      );
      await tester.tap(find.text('Import a subscription without signing in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'file:///tmp/sub.yaml',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('URL must be a URL'), findsOneWidget);
      expect(api.downloads, 0);
      await tester.enterText(
        find.byType(TextFormField),
        '  https://example.com/subscription  ',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(browser.registered, isNull);
      expect(container.read(ipingSessionProvider).account, isNull);
      expect(container.read(ipingSessionProvider).canConnect, isTrue);
      expect(storage.stored?.manualUrl, 'https://example.com/subscription');
    },
  );

  testWidgets(
    'manual import shows progress and failure without browser waiting',
    (tester) async {
      await pump(tester, const IpingGate(child: Text('HOME')));
      await tester.ensureVisible(
        find.text('Import a subscription without signing in'),
      );
      await tester.tap(find.text('Import a subscription without signing in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/sub',
      );
      final download = api.download = Completer();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('Complete sign-in'), findsNothing);
      download.completeError(const IpingException(IpingFailure.subscription));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsNothing);
      expect(find.byType(IpingFailureText), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(storage.stored, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual import cancel leaves the subscription unchanged', (
    tester,
  ) async {
    await pump(tester, const IpingLoginView());
    await tester.ensureVisible(
      find.text('Import a subscription without signing in'),
    );
    await tester.tap(find.text('Import a subscription without signing in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.downloads, 0);
    expect(storage.stored, isNull);
  });

  testWidgets(
    'manual subscription details refresh and replace the saved link',
    (tester) async {
      storage.stored = const IpingStoredSession(
        manualUrl: 'https://example.com/old',
      );
      await pump(tester, const IpingSubscriptionDetails());
      expect(find.text('Manually imported subscription'), findsOneWidget);
      expect(find.text('Sign in with browser'), findsOneWidget);
      expect(find.text('Open iPing console'), findsNothing);
      await tester.tap(find.text('Import subscription link'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'https://example.com/old',
      );
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/new',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(storage.stored?.manualUrl, 'https://example.com/new');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(api.subscriptionUrlRequested, 'https://example.com/new');
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(1360, 860),
      const Size(390, 844),
      const Size(320, 568),
    ]) {
      testWidgets('login adapts to ${size.width} in ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = ThemeData(
          colorScheme: seededColorScheme(
            seedColor: const Color(0xFF146B65),
            brightness: brightness,
          ),
        ).withAppShapes.withAppSurfaces.withAppTypography;

        await pump(tester, const IpingGate(child: Text('HOME')), theme: theme);

        if (size.width >= 960) {
          expect(find.text('Your device'), findsOneWidget);
          expect(
            tester.getRect(find.text('Welcome to iPing')).left,
            greaterThan(tester.getRect(find.text('iPing')).right),
          );
        } else {
          expect(find.text('Your device'), findsNothing);
        }
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        expect(find.text('HOME'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('large text and long public branding remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    api.siteSettings = IpingSiteConfig(
      name: 'A longer name for your network services',
      description: List.filled(
        6,
        'Manage your network connections in one account.',
      ).join(' '),
    );

    await pump(tester, const IpingGate(child: Text('HOME')));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login displays public branding and a cached SVG logo', (
    tester,
  ) async {
    api.siteSettings = const IpingSiteConfig(
      name: 'Custom brand',
      description: 'Public site introduction',
      logoUrl: 'https://example.com/branding.svg',
    );
    readRemoteIcon = (_) => Stream.value(
      Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" fill="red"/></svg>',
        ),
      ),
    );
    addTearDown(() => readRemoteIcon = null);

    await pump(tester, const IpingLoginView());

    expect(find.text('Welcome to Custom brand'), findsOneWidget);
    expect(find.text('Public site introduction'), findsOneWidget);
    expect(find.textContaining('Custom brand website'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed remote logo falls back to the bundled image', (
    tester,
  ) async {
    api.siteSettings = const IpingSiteConfig(
      logoUrl: 'https://example.com/missing-logo.png',
    );
    readRemoteIcon = (_) => Stream.error(StateError('image unavailable'));
    addTearDown(() => readRemoteIcon = null);

    await pump(tester, const IpingLoginView());

    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage('assets/images/icon.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closed registration hides the button and rejects direct attempts',
    (tester) async {
      api.siteSettings = const IpingSiteConfig(allowRegister: false);
      await pump(tester, const IpingLoginView());

      expect(find.text('Create an account'), findsNothing);
      await container
          .read(ipingSessionProvider.notifier)
          .controller
          .signIn(register: true);

      expect(browser.registered, isNull);
      expect(storage.value, isNull);
      expect(find.text('Sign in with browser'), findsOneWidget);
    },
  );

  testWidgets('a pending public configuration request never blocks login', (
    tester,
  ) async {
    final request = api.siteRequest = Completer<IpingSiteConfig>();
    await pump(tester, const IpingGate(child: Text('HOME')));

    expect(find.text('Welcome to iPing'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    request.complete(const IpingSiteConfig());
    await container.read(ipingSiteConfigProvider.notifier).refresh();
  });

  testWidgets('browser login can be canceled without saving credentials', (
    tester,
  ) async {
    await pump(tester, const IpingLoginView());
    browser.pending = Completer();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Complete sign-in'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Forgot password?'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.value, isNull);
    expect(container.read(ipingSessionProvider).busy, isFalse);
    expect(find.text('Sign in with browser'), findsOneWidget);
    browser.pending = null;
  });

  testWidgets('registration returns through the same subscription login flow', (
    tester,
  ) async {
    await pump(tester, const IpingGate(child: Text('HOME')));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(browser.registered, isTrue);
    expect(find.text('HOME'), findsOneWidget);
    expect(storage.value?.id, 7);
  });

  testWidgets(
    'successful callback opens the gate and loads subscription without connecting',
    (tester) async {
      await pump(tester, const IpingGate(child: Text('HOME')));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(storage.value?.id, 7);
      // The only stop is orphan cleanup at initialization; login never starts VPN.
      expect(profiles.stops, 1);
      await container.read(ipingSessionProvider.notifier).controller.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Sign in with browser'), findsOneWidget);
    },
  );

  testWidgets('an empty subscription offers refresh and manual import', (
    tester,
  ) async {
    api.nodes = 0;
    await pump(tester, const IpingLoginView());
    await container.read(ipingSessionProvider.notifier).controller.signIn();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: IpingSubscriptionDetails()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No available nodes'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Add profile'), findsNothing);
    expect(container.read(ipingSessionProvider).canConnect, isFalse);
    final siteRequests = api.siteRequests;
    final downloads = api.downloads;

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(api.siteRequests, siteRequests + 1);
    expect(api.downloads, downloads + 1);
  });

  testWidgets('account actions and branding remain available after login', (
    tester,
  ) async {
    await pump(tester, const IpingGate(child: ToolsView()));
    final clip = tester.widget<ClipPath>(
      find.descendant(
        of: find.byType(IpingLogo),
        matching: find.byType(ClipPath),
      ),
    );
    final path = clip.clipper!.getClip(const Size.square(48));
    expect(path.contains(Offset.zero), isFalse);
    expect(path.contains(const Offset(24, 24)), isTrue);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Personal center'), findsNothing);
    expect(find.textContaining('User ID'), findsNothing);
    expect(find.byType(IpingAccountButton), findsNothing);
    expect(find.byType(CommonPopupMenu), findsNothing);
    expect(find.text('Open iPing console'), findsOneWidget);
    expect(find.text('Contact support'), findsNothing);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with browser'), findsOneWidget);
    expect(storage.value, isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'mobile account actions are flat at $width in ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          api.siteSettings = const IpingSiteConfig(
            name: 'A longer name for your network services',
          );
          storage.value = const IpingAccount(
            id: 7,
            email: 'a.long.account.email.address@example.com',
            subscriptionToken: 'subscription',
          );
          final theme = ThemeData(
            colorScheme: seededColorScheme(
              seedColor: const Color(0xFF146B65),
              brightness: brightness,
            ),
          ).withAppShapes.withAppSurfaces.withAppTypography;

          await pump(
            tester,
            const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: IpingAccountSection(),
              ),
            ),
            theme: theme,
          );

          expect(find.text(api.siteSettings.name), findsOneWidget);
          expect(find.text(storage.value!.email), findsOneWidget);
          expect(find.text('Open iPing console'), findsOneWidget);
          expect(find.text('Sign out'), findsOneWidget);
          expect(find.byType(IpingAccountButton), findsNothing);
          expect(find.byType(CommonPopupBox), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('mobile console action opens the external link confirmation', (
    tester,
  ) async {
    storage.value = await api.authenticate();
    await pump(tester, const Scaffold(body: IpingAccountSection()));

    await tester.tap(find.text('Open iPing console'));
    await tester.pumpAndSettle();

    expect(find.byType(CommonDialog), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText(),
      '$ipingSite/home',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CommonDialog), findsNothing);
  });

  testWidgets('mobile sign out is disabled during a subscription refresh', (
    tester,
  ) async {
    storage.value = await api.authenticate();
    await pump(tester, const Scaffold(body: IpingAccountSection()));
    api.download = Completer<IpingSubscription>();
    final refresh = container.read(ipingSessionProvider.notifier).synchronize();
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('Sign out'),
      matching: find.byType(ListItem),
    );

    expect(tester.widget<ListItem>(row).onTap, isNull);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(container.read(ipingSessionProvider).account, isNotNull);

    api.download!.complete((bytes: Uint8List(0), nodes: 2));
    await refresh;
    await tester.pumpAndSettle();
    expect(tester.widget<ListItem>(row).onTap, isNotNull);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsNothing);
    expect(storage.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile account actions disappear when sign out storage fails', (
    tester,
  ) async {
    storage.value = await api.authenticate();
    await pump(tester, const Scaffold(body: IpingAccountSection()));
    storage.clearFails = true;

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Open iPing console'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(container.read(ipingSessionProvider).failure, IpingFailure.storage);
    expect(tester.takeException(), isNull);
  });

  for (final width in [48.0, 220.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'sidebar account opens actions at $width in ${brightness.name}',
        (tester) async {
          await container
              .read(ipingSessionProvider.notifier)
              .controller
              .initialize();
          await container
              .read(ipingSessionProvider.notifier)
              .controller
              .signIn();
          final theme = ThemeData(
            colorScheme: seededColorScheme(
              seedColor: const Color(0xFF146B65),
              brightness: brightness,
            ),
          ).withAppShapes.withAppSurfaces.withAppTypography;
          await pump(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: width,
                  child: const IpingAccountButton(),
                ),
              ),
            ),
            theme: theme,
          );

          expect(
            find.text('user@example.com'),
            width > 100 ? findsOneWidget : findsNothing,
          );
          await tester.tap(find.byTooltip('Account\nuser@example.com'));
          await tester.pumpAndSettle();

          expect(find.text('Open iPing console'), findsOneWidget);
          expect(find.text('Contact support'), findsNothing);
          await tester.tap(find.text('Sign out'));
          await tester.pumpAndSettle();

          expect(storage.value, isNull);
          expect(container.read(ipingSessionProvider).account, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'account menu disables sign out while a subscription refresh is pending',
    (tester) async {
      await container
          .read(ipingSessionProvider.notifier)
          .controller
          .initialize();
      await container.read(ipingSessionProvider.notifier).controller.signIn();
      api.download = Completer<IpingSubscription>();
      final refresh = container
          .read(ipingSessionProvider.notifier)
          .synchronize();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: SizedBox(width: 220, child: IpingAccountButton()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account\nuser@example.com'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommonPopupMenu>(find.byType(CommonPopupMenu))
            .items
            .last
            .onPressed,
        isNull,
      );

      api.download!.complete((bytes: Uint8List(0), nodes: 2));
      await refresh;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommonPopupMenu>(find.byType(CommonPopupMenu))
            .items
            .last
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop settings shows app version and policies without account actions',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'iPing',
        packageName: 'my.iping.client',
        version: '1.2.3',
        buildNumber: '42',
        buildSignature: '',
      );
      container.read(viewSizeProvider.notifier).value = const Size(1400, 1000);
      await container
          .read(ipingSessionProvider.notifier)
          .controller
          .initialize();
      await container.read(ipingSessionProvider.notifier).controller.signIn();
      await pump(tester, const ToolsView());

      expect(find.byType(IpingAccountSection), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      await tester.scrollUntilVisible(find.byType(IpingAboutSection), 400);
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Version 1.2.3 (42)'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
