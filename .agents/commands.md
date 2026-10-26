# Commands

## Building

Update submodules first. The ClashMeta Go core lives in `core/Clash.Meta/`.

```bash
git submodule update --init --recursive
```

Full package build, including Go core, Flutter, and packaging, runs through `setup.dart`:

```bash
dart setup.dart macos
dart setup.dart linux
dart setup.dart windows
dart setup.dart android
dart setup.dart ios # macOS host, signed App Store IPA
```

The experimental iOS target also builds through `flutter build ios --debug`, with
its Go XCFramework built by the Runner scheme pre-action. `setup.dart ios` packages
a signed release/AOT IPA containing the packet tunnel extension. Signing secrets,
simulator checks and the native test command are in `ios/README.md`.

The desktop Go core and the Rust helper build automatically: Flutter runs
`plugins/setup/hook/build.dart` on every `flutter build` and `flutter test`,
and the hook drives `CoreBuilder` from the `setup_hooks` package in
`plugins/setup/setup_hooks/`. Artifacts land in `libclash/`. Android's Core is
the AAR the `:core` Gradle module builds with `gomobile bind` before anything
compiles against it; that needs `go` on `PATH` and nothing else, since the
gomobile tools come from `core/go.mod` and the NDK from AGP. The hook reruns only when Go, Rust, or
`setup_hooks` inputs change; the fingerprint cache lives in
`.dart_tool/setup_build_cache/`. To force a rebuild, delete that directory:

```bash
rm -rf .dart_tool/setup_build_cache
```

Flutter hides the hook's output on success, so to see why the Core was or was
not rebuilt read `.dart_tool/setup_build_cache/hook.log`; each invocation starts
with a `===` line carrying its timestamp and target.

The hook runs for `flutter test` and for `dart run` of any root-package script
too, so a pure Dart test run needs the Go toolchain, and on Linux and Windows
also `cargo` and `rustc` — the Helper fingerprint shells out to both even on a
cache hit. The hook protocol carries no build mode and no caller, so the only
switch is the user-define in the root `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    setup:
      build_assets: true   # false turns the Go core and Helper hook into a no-op
    rust_api:
      build_assets: true   # false does the same for the Rust library
```

Metadata-only tooling can set both hooks to `false` in its throwaway checkout.
Editor and IPC socket tests need `rust_api` enabled; no test loads the Go Core.
Never commit `false`: a build with it set stages whatever `libclash/` already
holds and bundles no Rust library, which is why `setup.dart` refuses to package
while it is set. Locally, `false` is worth setting for a Dart-only test loop,
but the hook cache keys on the user-define, so the first build afterwards runs
the hooks again. The editor and IPC socket tests still need the Rust library: keep `rust_api`
on, or point `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` at a directory that
holds a `rust_api` library built from the same sources.

## iPing Updates

Release builds check `https://video.iping.my/releases/latest.json` at startup,
on resume (at most once every five minutes), and hourly. A newer version blocks
normal navigation and connections until installed; a known required update is
cached across restarts and remains required while offline. Debug and safe mode
builds do not check for updates. Override the base URL at build time with
`--dart-define=IPING_UPDATE_BASE_URL=https://example.com/releases/`.

Build all existing architectures with `setup.dart` and collect their `dist/`
artifacts in one directory. macOS also produces a ZIP with `ditto` to preserve
framework symlinks and signatures; Linux produces ZIP, DEB, RPM, and AppImage.
Publish through the existing `minio` rclone remote:

```bash
bash tool/publish_update.sh --artifacts dist
```

The publisher requires the full platform matrix, computes SHA-256 and sizes,
uploads immutable `<version>+<build>/` packages into `iping/releases/`, checks the
uploads, then replaces `latest.json` last. Bump `pubspec.yaml` before each release.
Use `--allow-partial` only with a separate test bucket/path and base URL; clients
whose platform is missing cannot install that release.

Dispatch `build.yaml` with a commit SHA or branch in `ref` (default `main`). It
resolves that ref once, reads the version from `pubspec.yaml`, and publishes the
exact commit directly to MinIO; no GitHub
Release attachments or Actions artifacts are uploaded. Signed iOS IPA and Linux
Agent ZIPs are included alongside the desktop and Android packages. The Linux Agent
builds once per CPU family and shares its Web interface between OpenWrt and ordinary
Linux. The installer selects procd/UCI/cron on OpenWrt and systemd/JSON/timers on Linux.
`install-linux.sh` is published at the stable download root. `publish_stable=false` publishes preview downloads under a run-specific prefix
without changing the stable installer or update manifest.

Cross-job Web assets and packages use verified receipts under
`iping/releases/builds/<run-id>/`. Source SHA, full version, build mode, size and SHA-256 are checked before
reuse. The public manifest records `sourceCommit`; Git tags are optional. Release objects are immutable and are downloaded for verification before
`latest.json` changes. All jobs share the existing `relayx-org` runners. MinIO ingress
must permit S3 uploads under `/iping/releases/`; configure `MINIO_ACCESS_KEY_ID` and
`MINIO_SECRET_ACCESS_KEY` as repository secrets. Credentials stay out of binaries and
manifests.

Android uses `ota_update` and requires the same APK signing key as the installed
app. CI requires `KEYSTORE` (base64 JKS), `KEY_ALIAS`, `STORE_PASSWORD`, and
`KEY_PASSWORD`; missing signing secrets fail the build before publishing a
development APK. Windows runs the existing Inno Setup installer and restarts after installation;
Authenticode is optional. macOS replaces the app bundle after verifying its code
signature. macOS release jobs import `MACOS_CERTIFICATE` (base64 Developer ID P12)
with `MACOS_CERTIFICATE_PASSWORD` and sign with `CODESIGN_IDENTITY`. Apple notarization
uses `APPLE_API_PRIVATE_KEY` (base64 P8), `APPLE_API_KEY`, and `APPLE_API_ISSUER`.
The packaging hook signs and notarizes the app before creating both DMG and ZIP.
iOS reuses GoRelay's `IOS_CERTIFICATE` (base64 Apple Distribution P12) and
`IOS_CERTIFICATE_PASSWORD` convention. It requires iPing-specific App Store profiles
in `IOS_PROVISIONING_PROFILE` and `IOS_TUNNEL_PROVISIONING_PROFILE`; both must enable
the VPN and App Group capabilities. See `ios/README.md`. This workflow exports an
IPA without uploading to TestFlight or App Store Connect.
Linux uses the system package manager with elevation for DEB/RPM,
or replaces the writable AppImage/ZIP installation. System permission and Android
installation confirmations still apply.

## iPing Client Authentication

The `iping` website confirms browser sign-in through `POST /api/user/client-login`.
The backend's `api_key` is the subscription token; its `access_key` is the API
credential. The callback carries a one-time code and state; the client exchanges
the code using its PKCE verifier and saves both credentials in secure session storage. Older sessions
without an API key remain usable for subscriptions.

Authenticated reads use `ref.read(ipingAuthenticatedApiProvider).get<Map<String, dynamic>>('user/info')`.
The public `ipingApiProvider` handles site configuration, browser login URLs and subscriptions;
the session depends only on that public client, keeping API credential lookup out of its dependencies.
The client reads the current account's API key for each request, sends it in the
Bearer header, and restricts requests to the configured site's API paths without
following redirects. Public site configuration and subscription downloads remain
anonymous. Deploy the website and backend changes, then sign in again to add the
API key to an existing client session.

Connection diagnostics read `user/info` for account authorization and check system DNS separately
from the existing routed exit probe. Account operations remain in the sidebar footer or the mobile settings menu.

## Flutter Development

Use the default Flutter SDK directly:

```bash
flutter pub get
flutter run
flutter test
```

Use `flutter test`, not `dart test`, because models pull in Flutter types.

A development build takes over the host exactly like a release: it creates the TUN device, sets the system proxy, on
macOS rewrites the system DNS, registers itself as the login item, and on Windows and Linux starts its Core through the
shared privileged Helper, which stops the Core an installed FlClash is running. Only the data directory is kept apart,
and only for some builds: a macOS debug build is `com.follow.clash.debug` and an Android debug build `com.follow.clash.dev`,
while profile and release builds, and every build on Windows and Linux, share the directory and preferences of the
installed app. Safe mode keeps all of the host changes off and never opens the Core's listeners or external
controller, so it does not compete with the installed app for the mixed, DNS, RESTful API and other loopback ports:

```bash
flutter run --dart-define-from-file=env.json --dart-define=SAFE_MODE=true
```

`.run/main_safe_mode.run.xml` is the same launch for IntelliJ, and `Flutter App (Safe Mode)` in `.zed/debug.json` (debugger) or `flutter run (Safe Mode)` in `.zed/tasks.json`
(plain run) for Zed. The build is bannered `SAFE MODE`, the tray shows the
`status_4` bug icon with a menu of only show and exit and no traffic title, and the settings keep their values, so
nothing has to be flipped back before a normal run. See the safe mode section of `architecture.md` for the owners that consult the flag.

## Code Generation

Run code generation after modifying models, providers, or database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch
```

Code generation covers:

- Riverpod providers through `riverpod_generator`.
- Models through `freezed` and `json_serializable`.
- Database tables through `drift_dev`.

The Dart-Rust bindings in `plugins/rust_api` are generated by `flutter_rust_bridge_codegen` from
`plugins/rust_api/flutter_rust_bridge.yaml`; rerun it from that directory after changing anything under
`rust/src/api/`:

```bash
cd plugins/rust_api && flutter_rust_bridge_codegen generate
```

Generated output paths, configured in `build.yaml`:

- `lib/models/generated/*.g.dart`, `*.freezed.dart`.
- `lib/providers/generated/*.g.dart`.
- `lib/database/generated/*.g.dart`.

Tray and desktop app icons are generated, not hand-edited. `assets/images/icon.png` is the source of
truth; the script needs `rsvg-convert` (librsvg) on `PATH`:

```bash
dart run tool/generate_status_icons.dart
```

It clips the icon to a superellipse and writes every tray from it: PNGs with Flutter `2.0x/`–`4.0x/`
resolution variants to `assets/images/tray/unix/` and `assets/images/tray/macos/`, and multi-size `.ico`
files to `assets/images/tray/windows/`. `status_1` (stopped) is grayscale, `status_2` (running) is the
plain icon, and `status_3` (TUN) and `status_4` (safe mode) add a colored badge. The same shape becomes
`windows/runner/resources/app_icon.ico`, `assets/images/linux/app_icon.png`, the iOS app and launch icons, and the macOS
`AppIcon.appiconset`, which keeps Apple's 824-on-1024 margin. iOS uses an opaque square app icon and lets the system
apply its icon mask. `assets_source/images/icon/glyph.svg` is
only the site favicon and the geometry of the Android notification drawables
`android/service/src/main/res/drawable/ic.xml` and `ic_service.xml`; change them together. `pubspec.yaml`
declares the tray directories and `assets/images/linux/` with `platforms:` so each build only bundles
what it loads; a new status icon needs an entry in the script's `trayVariants`, nothing in `pubspec.yaml`.

## Testing

Tests use `package:test/test.dart` for pure Dart logic and `flutter_test` for provider and widget tests. `mocktail` is the mocking framework.

```bash
flutter test test/models/
flutter test test/core/
flutter test test/core/desktop/
flutter test test/providers/
flutter test test/common/
flutter test test/database/
flutter test test/widgets/
flutter test test/setup_test.dart
flutter test plugins/proxy/test/proxy_test.dart
```

For the whole suite, or a directory of more than a few files, use `tool/test.dart`:

```bash
dart run tool/test.dart                                  # all of test/
dart run tool/test.dart test/widgets test/views          # some paths
dart run tool/test.dart -- --reporter expanded --coverage
```

Plain `flutter test` compiles each file into its own program and starts an engine for it, one file after another, and
that dominates a full run: 329 files took 128 s on a 12-core Mac with at most four running at once. `tool/test.dart`
imports the files into 32 generated entrypoints under `.dart_tool/test_bundles/` and runs those with one worker per
core: about 60 s for the same run, and 67 s instead of 180–213 s with `--coverage`. Files in one entrypoint share an
isolate, so a test can see state a file before it left behind; the script runs every file that failed there again on
its own, lets that run decide, and names the files that only failed together. See the Shared Test Isolate section of
`rules.md` before fixing one.

`plugins/setup/setup_hooks/` is a pure Dart package and is tested with `dart test` from its own directory, which is
the command to run locally; `tool/check_plugins.sh` does not descend into it. It must stay out of `flutter test`, because a test
run of `plugins/setup` would execute the build hook itself.

Native plugin code under `plugins/*/{linux,macos,windows}` is compiled by the release matrix.
Use `flutter build <platform> --debug` locally for focused native checks; `tool/check_plugins.sh`
only analyzes and tests the Dart side.

Root `flutter test` only discovers the root package's `test/` directory by default. Include bundled plugin Dart tests by passing paths explicitly, or run `flutter test` from that plugin package directory, or run `bash tool/check_plugins.sh` to analyze and test every plugin package locally. Native plugin tests under platform folders are not run by `flutter test`.

For the current Core/service architecture, useful focused checks are:

```bash
flutter test test/core/desktop/
flutter test test/core/service_test.dart
flutter test test/core/protocol_contract_test.dart
flutter test test/manager/core_manager_test.dart
flutter test test/providers/action_test.dart test/providers/system_action_test.dart
flutter test test/widgets/core_status_button_test.dart
```

What those suites own:

- `test/core/desktop/`: replaceable IPC transport, RPC request correlation/failure, direct/Helper process leases, and
  latest-intent desktop lifecycle convergence. `ipc_native_test.dart` runs the transport over a real socket through
  the Rust `IpcServer`; the server's own behavior is covered by `cargo test` in `plugins/rust_api/rust`.
- `test/core/service_test.dart`: `CoreService` composition and terminal close behavior.
- `test/core/protocol_contract_test.dart`: shared Dart/Go method and event-envelope compatibility, including event batches.
- `test/providers/action_test.dart`: Core start/restart orchestration and overlapping restart requests.
- `test/providers/system_action_test.dart`: ordered, idempotent exit cleanup and watchdog behavior.
- `test/widgets/core_status_button_test.dart`: 600-millisecond connecting presentation hold, immediate failure display,
  long-running connecting state, and disconnected restart.

## Native Component Verification

Run the Go-wrapper checks without CGO, the Android files included:

```bash
cd core
CGO_ENABLED=0 go test .
CGO_ENABLED=0 go vet . ./cmd/...
GOOS=android GOARCH=arm64 CGO_ENABLED=0 go vet -tags=with_gvisor . ./mobile ./tun ./platform
```

The Windows Helper's loopback/session protocol tests are host-independent by default. On Windows, also enable its
service implementation:

```bash
cargo fmt --manifest-path services/helper/Cargo.toml -- --check
cargo test --manifest-path services/helper/Cargo.toml
cargo test --manifest-path services/helper/Cargo.toml --features windows-service
```

The last command requires Windows for meaningful service coverage. Native Android lifecycle edits should at minimum
compile the modules they touch, with the JDK 17 that CI installs. On macOS the Homebrew `openjdk@17` keg is not
registered with `java_home`, so export it by prefix:

```bash
cd android
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"   # elsewhere: any JDK 17
./gradlew :core:compileDebugKotlin -Ptarget-platform=android-arm64   # builds the gomobile AAR for one ABI
./gradlew :service:compileDebugKotlin
./gradlew :app:compileDebugKotlin
```

Always-on VPN entry, system VPN revoke, actual permission UI, and rapid device start/stop still require Android device or
emulator validation; Kotlin compilation cannot prove those system callbacks.

## Changelog And Release

The changelog is derived from Conventional Commits by `tool/changelog.dart` and written to two committed files:
`CHANGELOG.md` for readers and `changelog.json` for the renderers. See `.agents/rules.md` for the `Changelog:` trailers
that decide the wording.

The app ships no changelog of its own. `render release` appends the released version as JSON inside an HTML comment
(`<!-- flclash:changelog:json … -->`), so the release body GitHub already returns to `checkForUpdate` carries the
notes shown in the update dialog. `parseReleaseChangelog` reads that block and falls back to the English
bullets when a release predates it.

```bash
dart run tool/changelog.dart verify                  # verify generated release notes
dart run tool/changelog.dart release --version 0.1.0
dart run tool/changelog.dart build --unreleased      # changelog.json only, includes untagged work
dart run tool/changelog.dart render release --out release.md
dart run tool/changelog.dart render telegram --out telegram.md
```

Releasing a stable version, in order:

```bash
tool/bump_version.sh minor # use all when also bumping the app patch version
git commit -am "chore(release): bump build number"
git push origin main
gh workflow run build.yaml --repo relayx-org/FlClash --ref main -f ref="$(git rev-parse HEAD)"
```

No new Git tag or GitHub Release is required. `release.yaml` remains an optional
tag-push shortcut and passes that ref to the same workflow. Existing tags are not
moved when rebuilding a pending MinIO release.

The changelog renderer can still use Git tags for historical release notes.
CI never writes back to the repository; verify the changelog locally before publishing. Wording in
`changelog.json` may be edited by hand as long as no derivable entry disappears and every entry still points at a commit
inside that version's range.

The upstream history at commit `8d4f9744948751f1273fe871e1d05276fac09b0e` is frozen
under the `<!-- changelog:frozen -->` marker in `CHANGELOG.md`. iPing starts a new
version series at `0.1.0`; the builder excludes tags already reachable at that baseline.
The initial fork release uses `release --freeze-history` once to preserve all upstream notes.

`verify` compares a version only when its tag is reachable from `HEAD`, because that is the same scope the builder walks
(`git tag --merged`). A branch cut before the newest release cannot derive that version at all, so `verify` names it as
skipped and moves on instead of reporting drift that does not exist. Checking mere tag existence is what made every such
branch fail on an unrelated release.

Prerelease tags (`v0.1.0-pre.N`) skip the release commit. Their builds publish
versioned MinIO packages without updating the production manifest. Generate their notes with `build --unreleased` before
rendering; this reads the base version from `pubspec.yaml`, which must be bumped
before the first prerelease of a cycle.

### Website

`site/` is the GitHub Pages site: a static page that renders `CHANGELOG.md` and the download links in the browser, and
works as is for local previews. `tool/build_site.sh [dir]` assembles it with the preview images, the app icon,
`CHANGELOG.md` read at the latest release tag, and a `release.json` of asset names, sizes and digests fetched through
`gh`. Without `gh` access the page falls back to the newest version in `CHANGELOG.md` and lists the files without sizes.
It then runs `tool/render_site.mjs` (Node), which writes the English page and a `zh/` copy for search engines: page
text, the first changelog releases, canonical and `hreflang` links, JSON-LD and `sitemap.xml`, all from the strings,
changelog parser and release markup in `site/assets/shared.js`, plus the GitHub star count from `release.json` so the
nav does not grow when the page loads. `SITE_URL` overrides the published URL these point at.
On the built site each URL keeps its language: the language button links to the other page and carries the section in
view, the chosen platform and the changelog search. Only the English root sends readers who chose or prefer Chinese on
to `zh/`, unless its URL carries `?lang=en`: the button on `zh/` links there with it, so getting back to English never
depends on browser storage. A project site cannot serve the `robots.txt` that would announce the sitemap, so submit
`sitemap.xml` in Google Search Console and Bing Webmaster Tools once.

```bash
tool/build_site.sh && python3 -m http.server -d build/site
```

The page's look is deliberate: low-saturation flat colour, no blur, glow, glass or soft shadow, and motion that follows
the logo's 30° lattice. `site/assets/field.js` draws the hero's capsules on that lattice with the glyph's own
proportions, and the slanted wipes, the dot-to-bar marks and the theme transition reuse the same angle. Text that sits
inside the hero has to be listed in `wireField` in `app.js`, or the capsules run behind it.

`.github/workflows/pages.yaml` deploys the site only when manually triggered; its
Pages source has to be set to GitHub Actions first. Website deployment is separate from app releases. The file names come from the
release matrix in `build.yaml`, so a renamed artifact needs the same change in `buildsFor` in `site/assets/app.js`.

## Verify

Run the local checks before committing:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/iping/
```

Use the covering test suites listed above for other changes. `build.yaml` resolves
the requested ref to an immutable commit; signing, storage and manifest tooling come
from the CI commit. Manual retries use that same source ref. Downloads and checksums go
directly to MinIO; only successful stable builds replace its update manifest.

### Self-hosted Release Builds

Organization runners use `[self-hosted, Linux, X64]`,
`[self-hosted, Windows, X64]`, and `[self-hosted, macOS, ARM64]`.
Windows and Linux publish x64 only; Android retains all three APK ABIs.
The Mac Studio builds both macOS architectures. Each job sets Xcode `ARCHS`
through a temporary `XCODE_XCCONFIG_FILE` and the matching
`hooks.user_defines.setup.macos_architecture` (`arm64` or `amd64`).
The Core hook and package filenames follow that selection; Rust also needs
`x86_64-apple-darwin` installed for Intel. Local builds default to the host.

`tool/ci/cache.sh` and `cache.ps1` keep build outputs, Core fingerprints,
Flutter hook/build caches, Rust targets, Pub, Gradle and npm under
`RUNNER_TOOL_CACHE/iping`, outside the cleaned checkout. Build caches are separated
by platform, architecture and checkout path; installed SDKs, Go caches and Cargo packages stay
on the runner. Remote Actions caches are disabled. Native Linux Go, Rust and Gradle builds
use two workers. Linux Agent cross-compilation runs on two Mac runners, with persistent
local Go module/build caches and verified Mihomo downloads. Five CPU families cover
all supported firmware versions without SDK, IPK or APK builds. The binary installer
handles runtime dependencies, procd/systemd startup, verified updates and activation rollback.
Windows uses a checksum-pinned portable Python under the runner tool cache for
MinIO transfers, without an MSI installation or registry changes.
Temporary signing keys are removed after each job without discarding
other jobs' entries in the Mac keychain search list.

To resume a release after changing only CI tooling, dispatch `build.yaml` with the same
`ref` and `reuse_run_id` of a completed MinIO build. Receipts must match the source
SHA, full version and stable/preview mode. It copies each completed native group,
Web build and Linux Agent group within MinIO, and only missing targets run again.
The binary installer is staged again from the current installer source.
The publisher caches packages by their verified MinIO receipt and checks their bytes
before reuse. Manifest generation invokes the Dart VM directly so it does not run
unrelated application native build hooks.

The repository lives at `relayx-org/FlClash` and shares the existing Debian,
Windows and Mac Studio organization runners. Their deployment sources live in
the Helm repository under `docker/github-runner/`; no repository-specific runner
instances are required. The organization runner group permits this public repository.

## Worktree Tooling

```bash
bash tool/worktrees.sh list       # every worktree with owner tool and dirty/clean state
bash tool/worktrees.sh prune      # remove clean worktrees; add --force to drop dirty ones too
```
