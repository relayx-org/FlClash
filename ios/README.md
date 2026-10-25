# iOS development

The iOS target is an experimental device/internal-test build, with iOS 15 as its
minimum. It reuses the Flutter application and Mihomo core. A real VPN connection
requires a physical iPhone and paid Apple Developer signing with Network
Extensions and App Groups enabled.

## Build and sign

Use the repository's Flutter SDK, Go, Rust and Xcode toolchains:

```sh
flutter pub get
flutter build ios --debug
```

For a signed AOT development IPA that can launch without a Flutter debugger:

```sh
flutter build ipa --release --export-method development
```

The IPA is written to `build/ios/ipa/`. Development signing limits installation
to devices registered with the team's provisioning profiles.

The shared release command builds and verifies a signed App Store IPA:

```sh
dart setup.dart ios --env stable
```

It uses `flutter build ipa --release`, then verifies the signatures, embedded
provisioning profiles and arm64 binaries of both `Runner.app` and `PacketTunnel.appex`
before copying the exported IPA to `dist/iPing-<version>-ios-arm64.ipa`. Set
`EXPORT_OPTIONS_PLIST` to use an explicit Xcode export configuration, as in GoRelay.
With explicit export options, compilation creates an archive first, then
`xcodebuild -exportArchive` signs the application and extension. Xcode-managed
profiles require automatic signing during export; manually created profiles use
an explicit bundle-to-profile map. CI exports with the installed profiles and
certificate without requesting provisioning updates from Apple.
App Store signing produces an IPA for App Store distribution; direct installation
on registered devices requires a development or ad hoc export instead.

The published-release workflow builds this IPA on the existing macOS ARM64 runner
and attaches it alongside the desktop, Android and OpenWrt packages with shared
checksums. Stable releases also copy it to the versioned download directory in the
existing MinIO storage. It only exports and publishes the IPA; it does not upload to
TestFlight or App Store Connect. The application's automatic updater remains disabled
on iOS.

CI follows the local GoRelay signing convention with these repository secrets:

| Secret | Content |
| --- | --- |
| `IOS_CERTIFICATE` | Base64 Apple Distribution P12; the GoRelay certificate can be reused |
| `IOS_CERTIFICATE_PASSWORD` | Password for that P12 |
| `IOS_PROVISIONING_PROFILE` | Base64 App Store profile for `my.iping.client` |
| `IOS_TUNNEL_PROVISIONING_PROFILE` | Base64 App Store profile for `my.iping.client.PacketTunnel` |

Both profiles must enable packet tunnels and `group.my.iping.client`, belong to
team `XGZ79JAGXJ`, and include the imported distribution certificate. GoRelay's profile
cannot be reused because it belongs to a different bundle ID. `tool/ci/ios_signing.py`
checks these requirements before building, maps profiles to each Xcode target, and
selects their matching Xcode export style. It cleans up its temporary keychain and
newly installed profiles after the job.

Open `Runner.xcworkspace` in Xcode to select a registered iPhone and run the
`Runner` scheme. Automatic signing uses team `XGZ79JAGXJ`, matching the local
GoRelay project. Change `DEVELOPMENT_TEAM` and the project-level
`IPING_APP_BUNDLE_ID` build setting for a different team or application ID.
Both targets must use the same team and App Group.

| Configuration | Application ID | Extension ID | App Group |
| --- | --- | --- | --- |
| Debug | `my.iping.client.debug` | `my.iping.client.debug.PacketTunnel` | `group.my.iping.client.debug` |
| Profile / Release | `my.iping.client` | `my.iping.client.PacketTunnel` | `group.my.iping.client` |

The Runner scheme builds `libclash/ios/Clash.xcframework` before Xcode resolves
its framework inputs. `tool/build_ios_core.dart` uses the gomobile version in
`core/go.mod`, the shared build configuration, and `with_low_memory`; its cache
covers sources and toolchain versions. It includes device arm64 and simulator
arm64/x86_64. Framework binaries and tool caches stay outside version control.
To build the framework separately:

```sh
dart tool/build_ios_core.dart
```

Rust native assets build through their existing Flutter hook. iOS uses the
mobile IPC/hotkey stubs, and rquickjs bindings are generated against Xcode's SDK.

## Safe UI checks

Agents run only safe-mode builds. For a simulator UI check:

```sh
flutter run -d <simulator-id> --dart-define=SAFE_MODE=true
```

Keep simulator code signing enabled: Xcode embeds the simulated App Group
entitlements needed to open shared storage. `--no-codesign` is suitable for
compilation checks, but its output cannot exercise shared storage. A simulator
cannot validate the real VPN path.

Native route tests run with the Runner scheme:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,id=<simulator-id>' \
  -only-testing:RunnerTests DART_DEFINES=U0FGRV9NT0RFPXRydWU= test
```

The encoded define sets `SAFE_MODE=true` for the test host application.

## Runtime ownership

`IOSService` serializes desired start/stop state through `NETunnelProviderManager`
and routes Core requests to the extension while connected. With the VPN stopped,
an application-local Core supports profile import, validation, and editing.
Configuration is fully applied before starting the extension. The application
detaches on shutdown; the independent VPN extension can remain running.

Both processes share Core configuration through the App Group. The Flutter
database and each process's bbolt cache stay in their private Application Support
directories: a persistent file lock in the App Group makes iOS terminate an app
on suspension with `0xdead10cc`, which also loses an in-progress browser login.
`PacketTunnelProvider` owns Network Extension settings and bridges
`packetFlow` to Mihomo through a datagram socket pair; it uses public packet-flow
APIs. Disabled IPv6 is captured and dropped. A bounded event mailbox separates
state from bulk events and expires its listener when the UI stops polling.

The extension uses a soft Go memory limit of 32 MiB; this is not an RSS ceiling.
Large profiles and provider updates still need device memory-pressure testing.
The desktop/Android package updater is disabled on iOS. Distribute updates through
signed IPA builds. Android per-app routing, system proxy
switching, Quick Settings and Wi-Fi SSID exclusions are not iOS features in this
first target.

Before distributing a build, verify VPN permission, actual TCP/UDP/DNS traffic,
IPv6 behavior, lock-screen/background operation, network changes, rapid toggles,
and a disconnect from iOS Settings on a signed device.
