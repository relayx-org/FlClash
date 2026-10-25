import 'package:fl_clash/models/common.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/iping/resource_controller.dart';
import 'dart:async';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/backend.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/browser.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import '../helpers/test_profiles.dart';
import 'package:fl_clash/models/state.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/enum/enum.dart' show ProfileType, ExtendType;
import 'package:fl_clash/models/clash_config.dart';

class _Browser extends IpingBrowserLogin {
  _Browser(this.api)
    : super(
        site: api.site,
        exchange: ({required code, required verifier}) =>
            throw UnimplementedError(),
      );

  final FakeIpingApi api;
  Completer<IpingAccount?>? pending;
  bool? registered;

  @override
  Future<IpingAccount?> signIn({bool register = false}) {
    registered = register;
    return pending?.future ?? api.authenticate(register);
  }

  @override
  void cancel() {
    if (pending case final request? when !request.isCompleted) {
      request.complete(null);
    }
  }
}

class _Setup extends SetupAction {
  final calls = <(bool, bool)>[];
  final modes = <Mode>[];
  bool accepted = true;

  @override
  void build() {}

  @override
  void changeMode(Mode mode) => modes.add(mode);

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    calls.add((running, initialize));
    return accepted;
  }
}

class _BindingSetup extends _Setup {
  SetupState? proposed;
  Completer<String>? validation;
  final entered = Completer<void>();
  int applies = 0;
  @override
  Future<String> validateResourceBindings(SetupState state) async {
    proposed = state;
    if (!entered.isCompleted) entered.complete();
    return validation == null ? '' : await validation!.future;
  }

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) =>
      applies++;
}

class _RuleResourcesAction extends ClashProvidersAction {
  final puts = <String>[];
  final removals = <String>[];

  @override
  Future<ClashProvider> putProvider(
    ClashProvider provider, {
    ClashProvider? previous,
    List<int>? content,
    bool refresh = false,
  }) async {
    puts.add(provider.label);
    await ref.read(clashProvidersProvider.notifier).putAsync(provider);
    return provider;
  }

  @override
  Future<void> delProviderAsync(ClashProvider provider) async {
    removals.add(provider.label);
    await ref.read(clashProvidersProvider.notifier).delAsync(provider.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeIpingApi api;
  late _Browser browser;
  late MemorySessionStorage storage;
  late MemoryProfileStorage profiles;
  late ProviderContainer container;
  late IpingBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeIpingApi(site: 'https://example.com');
    browser = _Browser(api);
    storage = MemorySessionStorage();
    profiles = MemoryProfileStorage();
    container = ProviderContainer(
      overrides: [
        ipingApiProvider.overrideWithValue(api),
        ipingBrowserProvider.overrideWithValue(browser),
        ipingStorageProvider.overrideWithValue(storage),
        ipingProfilesProvider.overrideWithValue(profiles),
      ],
    );
    backend = container.read(ipingBackendProvider);
  });
  tearDown(() => container.dispose());

  test(
    'native bindings validate the proposed profile before saving and reject a profile switch',
    () async {
      final memory = db.Database(NativeDatabase.memory());
      db.database = memory;
      const profile = Profile(
        id: 1,
        type: ProfileType.file,
        autoUpdateDuration: Duration.zero,
      );
      await memory.profilesDao.putAll([profile.toCompanion()]);
      await memory.rulesDao.putRule(
        const Rule(id: 11, content: 'example.com', ruleTarget: 'DIRECT'),
      );
      final setup = _BindingSetup();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([profile, profile.copyWith(id: 2)]),
          ),
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          setupActionProvider.overrideWith(() => setup),
          setupStateProvider.overrideWith(
            (_, _) => const SetupState(
              profileId: 1,
              profileLastUpdateDate: null,
              profileType: ProfileType.file,
              extendType: ExtendType.standard,
              rules: [],
              proxyGroups: [],
              addedRules: [],
              script: null,
              overrides: ProfileOverrides(),
            ),
          ),
        ],
      );
      addTearDown(() async {
        scoped.dispose();
        await memory.close();
      });
      final backend = scoped.read(ipingBackendProvider);
      final original = await backend.readProfileResources();
      final selected = IpingProfileResources(
        profileId: original.profileId,
        label: original.label,
        bindings: const IpingResourceBindings(rules: {'11'}),
      );
      await backend.updateProfileResources(selected);
      expect(setup.proposed!.addedRules.single.id, 11);
      expect((await backend.readProfileResources()).bindings.rules, {'11'});
      expect(setup.applies, 1);
      setup.validation = Completer<String>();
      final pending = backend.updateProfileResources(original);
      while (setup.proposed!.overrides.resources.rules.isNotEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      scoped.read(currentProfileIdProvider.notifier).value = 2;
      setup.validation!.complete('');
      await expectLater(pending, throwsA(isA<IpingResourceException>()));
      expect(scoped.read(profilesProvider).first.overrides.resources.rules, {
        '11',
      });
      expect(setup.applies, 1);
    },
  );

  test('account and subscription commands publish the shared state', () async {
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    expect((await backend.readState()).signedIn, isFalse);

    await backend.signIn(register: true);
    final state = await backend.readState();
    expect(browser.registered, isTrue);
    expect(state.initialized, isTrue);
    expect(state.signedIn, isTrue);
    expect(state.busy, isFalse);
    expect(state.email, 'user@example.com');
    expect(state.site, api.site);
    expect(state.nodes, api.nodes);
    expect(state.updated, profiles.value!.updated);
    expect(state.connected, isFalse);

    container.read(runTimeProvider.notifier).value = 1000;
    expect((await backend.readState()).connected, isTrue);
    expect(
      backend.capabilities,
      isNot(contains(IpingBackendCapability.routerNetwork)),
    );

    final downloads = api.downloads;
    await backend.synchronize();
    expect(api.downloads, downloads + 1);

    await backend.signOut();
    expect((await backend.readState()).signedIn, isFalse);
    expect((await backend.readState()).nodes, 0);
    expect(storage.value, isNull);
    expect(profiles.stops, greaterThan(0));
  });

  test('canceling sign-in keeps the account and subscription empty', () async {
    await container.read(ipingSessionProvider.notifier).controller.initialize();
    browser.pending = Completer<IpingAccount?>();
    final operation = backend.signIn();
    expect((await backend.readState()).busy, isTrue);
    backend.cancelSignIn();
    await operation;
    final state = await backend.readState();
    expect(state.signedIn, isFalse);
    expect(state.busy, isFalse);
    expect(api.downloads, 0);
  });

  for (final initialized in [false, true]) {
    test(
      'connection delegates to SetupAction with initialized=$initialized',
      () async {
        final setup = _Setup();
        final scoped = ProviderContainer(
          overrides: [
            setupActionProvider.overrideWith(() => setup),
            initProvider.overrideWithBuild((_, _) => initialized),
          ],
        );
        addTearDown(scoped.dispose);
        final backend = scoped.read(ipingBackendProvider);
        expect(await backend.setConnected(true), isTrue);
        setup.accepted = false;
        expect(await backend.setConnected(false), isFalse);
        expect(setup.calls, [(true, !initialized), (false, false)]);
      },
    );
  }

  test('mode changes delegate to the existing setup owner', () async {
    final setup = _Setup();
    final scoped = ProviderContainer(
      overrides: [setupActionProvider.overrideWith(() => setup)],
    );
    addTearDown(scoped.dispose);
    final backend = scoped.read(ipingBackendProvider);
    await backend.setMode(Mode.rule);
    await backend.setMode(Mode.global);
    expect(setup.modes, [Mode.global]);
  });
  test(
    'large native resource batches cross the isolate boundary and return canonical rows',
    () async {
      final memory = db.Database(NativeDatabase.memory());
      db.database = memory;
      final scoped = ProviderContainer(
        overrides: [profilesProvider.overrideWith(TestProfiles.new)],
      );
      addTearDown(() async {
        scoped.dispose();
        await memory.close();
      });
      final store = scoped.read(ipingBackendProvider).customProxies;
      final saved = await store.write([
        for (var index = 0; index < 64; index++)
          IpingCustomProxy(
            id: 'new-$index',
            definition: {'name': 'Node $index', 'type': 'direct'},
          ),
      ]);
      expect(saved, hasLength(64));
      expect(saved.map((item) => item.name), [
        for (var index = 0; index < 64; index++) 'Node $index',
      ]);
      expect(saved.every((item) => int.tryParse(item.id) != null), isTrue);
      expect(
        (await store.read()).map((item) => item.id),
        saved.map((item) => item.id),
      );
    },
  );

  test(
    'native proxy resources persist canonical ids, metadata, order and failures',
    () async {
      final memory = db.Database(NativeDatabase.memory());
      db.database = memory;
      final scoped = ProviderContainer();
      addTearDown(() async {
        scoped.dispose();
        await memory.close();
      });
      scoped.listen(customProxiesProvider, (_, _) {});
      final store = scoped.read(ipingBackendProvider).customProxies;
      final controller = IpingResourceController<IpingCustomProxy, String>(
        store,
        keyOf: (item) => item.id,
      );
      addTearDown(controller.dispose);
      await controller.load();
      final saved = await store.write([
        IpingCustomProxy(
          id: 'browser-new',
          definition: const {'name': 'Home', 'type': 'direct'},
          emptyOptions: const ['alpn'],
        ),
      ]);
      final id = saved.single.id;
      expect(int.tryParse(id), isNotNull);
      expect(id, isNot('browser-new'));
      expect(saved.single.emptyOptions, {'alpn'});
      expect((await memory.customProxiesDao.query().get()).single.name, 'Home');
      final renamed = await store.write([
        IpingCustomProxy(
          id: id,
          definition: const {'name': 'Renamed', 'type': 'direct'},
          emptyOptions: const ['alpn'],
        ),
        IpingCustomProxy(
          id: 'other-new',
          definition: const {'name': 'Other', 'type': 'direct'},
        ),
      ]);
      expect(renamed.first.id, id);
      final reordered = await store.write(renamed.reversed.toList());
      expect(reordered.map((item) => item.name), ['Other', 'Renamed']);
      expect(
        (await memory.customProxiesDao.query().get()).map((item) => item.name),
        ['Other', 'Renamed'],
      );
      await controller.load();
      await memory.customStatement(
        "CREATE TRIGGER reject_resource_delete BEFORE DELETE ON custom_proxies BEGIN SELECT RAISE(ABORT, 'fixture write failure'); END",
      );
      expect(await controller.remove({id}), isFalse);
      expect(controller.items!.map((item) => item.name), ['Other', 'Renamed']);
      expect(controller.busy, isFalse);
      expect(
        scoped.read(customProxiesProvider).value!.map((item) => item.name),
        ['Other', 'Renamed'],
      );
    },
  );
  test(
    'native rule resources keep lifecycle ownership and persist ordering',
    () async {
      final memory = db.Database(NativeDatabase.memory());
      db.database = memory;
      final action = _RuleResourcesAction();
      final scoped = ProviderContainer(
        overrides: [clashProvidersActionProvider.overrideWith(() => action)],
      );
      addTearDown(() async {
        scoped.dispose();
        await memory.close();
      });
      final store = scoped.read(ipingBackendProvider).ruleProviders;
      final stored = await store.write([
        const IpingRuleProvider(
          id: 'browser-one',
          label: 'One',
          url: 'https://example.com/one',
        ),
        const IpingRuleProvider(
          id: 'browser-two',
          label: 'Two',
          url: 'https://example.com/two',
        ),
      ]);
      expect(stored.map((item) => item.label), ['One', 'Two']);
      expect(action.puts, ['One', 'Two']);
      expect(stored.every((item) => int.tryParse(item.id) != null), isTrue);
      final reordered = await store.write(stored.reversed.toList());
      expect(reordered.map((item) => item.label), ['Two', 'One']);
      expect(action.puts, ['One', 'Two']);
      await store.write([reordered.first]);
      expect(action.removals, ['One']);
      expect((await store.read()).single.label, 'Two');
    },
  );
}
