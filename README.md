# iPing Client

Browser-based iPing login and automatic Mihomo subscriptions for Android, macOS, Windows, and Linux. Based on [FlClash](https://github.com/chen08209/FlClash), licensed under GPL-3.0; the original license and component notices are retained.

## Build

Use Flutter 3.47.6, Go 1.27, and the Rust toolchain pinned in `plugins/rust_api/rust/rust-toolchain.toml`.

```sh
git submodule update --init --recursive
flutter pub get
dart run intl_utils:generate
dart run build_runner build
dart setup.dart macos
```

Replace `macos` with `android`, `windows`, or `linux` on the corresponding host. Linux also needs libsecret development headers for secure account storage. See `.agents/commands.md` for platform prerequisites and checks.

## Account integration

Sign in through the iPing website using its existing Stack Auth interface (email, Google, or passkey). The `/client-login` page sends the subscription token back through `iping://auth/callback`, bound to the login request's random state. The client stores the subscription credential in system secure storage and loads `/api/tunnel/subscription?token=…` with a Clash User-Agent. It makes no Stack Auth requests and contains no Stack project configuration.

Deploy `apps/web/src/app/client-login` in the companion iping repository before using browser login. Only `IPING_SITE` is configurable at build time. Sign-out removes local credentials and account configuration without signing out of the website. The default interface language is Simplified Chinese; users can select another language in settings.

```sh
flutter run --dart-define=SAFE_MODE=true
flutter test test/iping
flutter analyze --no-fatal-infos
```

Safe mode keeps host VPN, proxy, DNS, and startup integrations inactive. Use a controlled device for actual VPN validation. Packaging does not publish releases automatically.
