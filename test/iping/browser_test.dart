import 'dart:async';

import 'package:fl_clash/iping/api.dart';
import 'package:fl_clash/iping/auth_session.dart';
import 'package:fl_clash/iping/browser.dart';
import 'package:flutter_test/flutter_test.dart';

const account = IpingAccount(
  id: 7,
  email: 'test@example.com',
  subscriptionToken: 'subscription-key',
  apiKey: '62ab74aa-0473-4790-9bd5-2f728dd42c56',
);
final code = 'c' * 43;

class FakeSession implements IpingAuthSession {
  final opened = <Uri>[];
  final schemes = <String>[];
  var cancels = 0;
  Completer<Uri?> result = Completer();

  @override
  Future<Uri?> authenticate(Uri url, {required String callbackScheme}) {
    opened.add(url);
    schemes.add(callbackScheme);
    return result.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (!result.isCompleted) result.complete(null);
  }
}

void main() {
  late IpingBrowserLogin browser;
  late Uri opened;
  late List<({String code, String verifier})> exchanges;

  Future<IpingAccount> exchange({
    required String code,
    required String verifier,
  }) async {
    exchanges.add((code: code, verifier: verifier));
    return account;
  }

  setUp(() {
    exchanges = [];
    browser = IpingBrowserLogin(
      exchange: exchange,
      open: (uri) async {
        opened = uri;
        return true;
      },
    );
  });
  tearDown(() => browser.cancel());

  Uri callback({String? state, String? code}) => Uri(
    scheme: 'iping',
    host: 'auth',
    path: '/callback',
    queryParameters: {
      'code': code ?? 'c' * 43,
      'state': state ?? opened.queryParameters['state']!,
    },
  );

  test(
    'opens the website with a PKCE challenge and redeems the code with its verifier',
    () async {
      final login = browser.signIn();
      await pumpEventQueue();
      expect(opened.path, '/client-login');
      expect(opened.queryParameters.keys, [
        'state',
        'code_challenge',
        'code_challenge_method',
      ]);
      expect(opened.queryParameters['state'], matches(r'^[A-Za-z0-9_-]{43}$'));
      expect(opened.queryParameters['code_challenge_method'], 'S256');
      expect(browser.handleCallback(callback()), isTrue);
      expect(await login, same(account));
      expect(exchanges.single.code, code);
      final verifier = exchanges.single.verifier;
      expect(verifier, matches(r'^[A-Za-z0-9_-]{43}$'));
      expect(
        IpingBrowserLogin.codeChallenge(verifier),
        opened.queryParameters['code_challenge'],
      );
      expect(browser.handleCallback(callback()), isFalse);
    },
  );

  test('uses the RFC 7636 S256 transformation', () {
    expect(
      IpingBrowserLogin.codeChallenge(
        'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
      ),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('every login uses a fresh verifier and state', () async {
    final challenges = <String>{};
    final states = <String>{};
    for (var i = 0; i < 3; i++) {
      final login = browser.signIn();
      await pumpEventQueue();
      challenges.add(opened.queryParameters['code_challenge']!);
      states.add(opened.queryParameters['state']!);
      expect(browser.handleCallback(callback()), isTrue);
      await login;
    }
    expect(challenges, hasLength(3));
    expect(states, hasLength(3));
    expect(exchanges.map((e) => e.verifier).toSet(), hasLength(3));
  });

  test('credentials in the callback URL are never accepted', () async {
    final login = browser.signIn();
    await pumpEventQueue();
    final state = opened.queryParameters['state']!;
    for (final uri in [
      Uri.parse('iping://auth/callback?token=key&id=7&email=a&state=$state'),
      Uri.parse('${callback()}&token=subscription-key'),
      Uri.parse('${callback()}&api_key=62ab74aa-0473-4790-9bd5-2f728dd42c56'),
    ]) {
      expect(browser.handleCallback(uri), isFalse, reason: '$uri');
    }
    browser.cancel();
    expect(await login, isNull);
    expect(exchanges, isEmpty);
  });

  test('ignores callbacks unrelated to the current browser login', () async {
    final login = browser.signIn();
    await pumpEventQueue();
    for (final uri in [
      callback(state: 'unrelated'),
      callback().replace(scheme: 'https'),
      callback().replace(host: 'install-config'),
      callback().replace(path: '/other'),
      callback().replace(fragment: 'extra'),
      callback(code: ''),
      callback(code: 'short'),
      callback(code: 'a b' * 15),
      Uri.parse('${callback()}&code=another'),
      Uri.parse('${callback()}&state=another'),
    ]) {
      expect(browser.handleCallback(uri), isFalse, reason: '$uri');
    }
    expect(browser.handleCallback(callback()), isTrue);
    expect(await login, isNotNull);
  });

  test(
    'registration preserves the return page and pending PKCE state',
    () async {
      final login = browser.signIn(register: true);
      await pumpEventQueue();
      expect(opened.path, '/handler/sign-up');
      final returnTo = Uri.parse(
        opened.queryParameters['after_auth_return_to']!,
      );
      expect(returnTo.path, '/client-login');
      expect(returnTo.queryParameters['code_challenge_method'], 'S256');
      final state = returnTo.queryParameters['state']!;
      expect(browser.handleCallback(callback(state: state)), isTrue);
      expect(await login, same(account));
      expect(
        IpingBrowserLogin.codeChallenge(exchanges.single.verifier),
        returnTo.queryParameters['code_challenge'],
      );
    },
  );

  test('a rejected code exchange surfaces as a session failure', () async {
    browser = IpingBrowserLogin(
      exchange: ({required code, required verifier}) =>
          Future.error(const IpingException(IpingFailure.session)),
      open: (uri) async {
        opened = uri;
        return true;
      },
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      final login = browser.signIn();
      await pumpEventQueue();
      expect(browser.handleCallback(callback()), isTrue);
      await expectLater(
        login,
        throwsA(
          isA<IpingException>().having(
            (e) => e.failure,
            'failure',
            IpingFailure.session,
          ),
        ),
      );
    }
  });

  test(
    'canceling login invalidates its state and a retry accepts only the new state',
    () async {
      final first = browser.signIn();
      await pumpEventQueue();
      final old = callback();
      browser.cancel();
      expect(await first, isNull);
      final second = browser.signIn();
      await pumpEventQueue();
      expect(browser.handleCallback(old), isFalse);
      expect(browser.handleCallback(callback()), isTrue);
      expect(await second, isNotNull);
    },
  );

  test('a browser launch failure allows retry', () async {
    browser = IpingBrowserLogin(exchange: exchange, open: (_) async => false);
    await expectLater(browser.signIn(), throwsA(isA<IpingException>()));
    await expectLater(browser.signIn(), throwsA(isA<IpingException>()));
  });

  test('a timed out login releases its pending callback', () async {
    browser = IpingBrowserLogin(
      exchange: exchange,
      open: (_) async => true,
      timeout: Duration.zero,
    );
    expect(await browser.signIn(), isNull);
    expect(await browser.signIn(), isNull);
  });

  test('an unsolicited callback cannot create a session', () {
    expect(
      browser.handleCallback(Uri.parse('iping://auth/callback?code=$code')),
      isFalse,
    );
  });

  group('system authentication session', () {
    late FakeSession session;
    var browserOpened = 0;

    setUp(() {
      session = FakeSession();
      browserOpened = 0;
      browser = IpingBrowserLogin(
        exchange: exchange,
        session: session,
        open: (uri) async {
          opened = uri;
          browserOpened++;
          return true;
        },
      );
    });

    test(
      'the sheet intercepts the callback without the external browser',
      () async {
        final login = browser.signIn();
        await pumpEventQueue();
        opened = session.opened.single;
        expect(session.schemes.single, 'iping');
        session.result.complete(callback());
        expect(await login, same(account));
        expect(browserOpened, 0);
        expect(session.cancels, 0);
      },
    );

    test('dismissing the sheet ends the login', () async {
      final login = browser.signIn();
      await pumpEventQueue();
      session.result.complete(null);
      expect(await login, isNull);
      expect(exchanges, isEmpty);
    });

    test('an invalid sheet callback ends the login', () async {
      final login = browser.signIn();
      await pumpEventQueue();
      opened = session.opened.single;
      session.result.complete(callback(state: 'unrelated'));
      expect(await login, isNull);
      expect(exchanges, isEmpty);
    });

    test(
      'a sheet that fails to start falls back to the external browser',
      () async {
        final login = browser.signIn();
        await pumpEventQueue();
        session.result.completeError(Exception('unavailable'));
        await pumpEventQueue();
        expect(browserOpened, 1);
        expect(opened, session.opened.single);
        expect(browser.handleCallback(callback()), isTrue);
        expect(await login, same(account));
      },
    );

    test('canceling or timing out closes the sheet', () async {
      final login = browser.signIn();
      await pumpEventQueue();
      browser.cancel();
      expect(await login, isNull);
      expect(session.cancels, 1);

      session = FakeSession();
      browser = IpingBrowserLogin(
        exchange: exchange,
        session: session,
        timeout: Duration.zero,
      );
      expect(await browser.signIn(), isNull);
      expect(session.cancels, 1);
    });
  });
}
