# iPing for OpenWrt

OpenWrt runs two packages: `iping` is the Agent with its embedded Flutter Web
interface; `iping-mihomo` supplies a private Mihomo binary. The Agent owns the
Core process, configuration, controller, and network cleanup. It does not depend
on Nikki, LuCI, or rpcd, and does not import their configuration.

The Web application reuses the native application's Flutter presentations,
localization, settings validation, and `IpingBackend` contract. Platform adapters
keep process ownership separate: native platforms retain their existing lifecycle
owners, while the router calls the Agent over a same-origin HTTP API. Device-only
features follow backend capabilities.

## Requirements

- OpenWrt 24.10 or newer with firewall4 and a Linux kernel supporting Mihomo's
  TUN auto-route and nftables auto-redirect (5.13 or newer).
- Enough storage and RAM for the embedded Flutter application and Mihomo.
  Generated Web assets omit unused native Geo databases and debug symbols.
- A current browser with WebAssembly support, and HTTPS access from the router
  to the configured iPing site.

The package manager installs `ip-full`, `nftables-json`, firewall4, CA certificates,
and the required TUN/netfilter modules. Use packages built for the router's exact
OpenWrt branch and architecture; kernel modules must match its running kernel.

## Build

Build the shared Web interface first:

```sh
bash openwrt/build_ui.sh
```

The script stages its output under `openwrt/iping/src/webui/dist/`. Go embeds those
files into the Agent, so there is no separate web server or static-file package.
Generated assets stay outside version control.

Add the local feed to an official OpenWrt SDK's `feeds.conf`:

```text
src-link iping /absolute/path/to/FlClash/openwrt
```

Then build both packages:

```sh
./scripts/feeds update -i iping
./scripts/feeds install -p iping iping-mihomo iping
make menuconfig
make package/feeds/iping/iping-mihomo/compile V=s
make package/feeds/iping/iping/compile V=s
```

Packages appear under `bin/packages/<architecture>/iping/`. Mihomo is pinned by
version and source checksum in `iping-mihomo/Makefile` and installs as
`/usr/libexec/iping/mihomo`.

The `openwrt` GitHub Actions workflow builds the Web interface once and uses the
SDK matrix for OpenWrt 24.10 and 25.12. It can run directly or be called by the
published-release workflow. Release builds use the resolved release SHA for Agent
tests, Web builds and every package job. The Agent and Web versions follow
`pubspec.yaml`; the package revision uses its build number.

Each download is `iPing-<version>-openwrt-<branch>-<arch>.zip`, containing matching
`iping` and `iping-mihomo` packages, `SHA256SUMS` and `INSTALL.txt`. OpenWrt 24.10
uses IPK packages and 25.12 uses APK packages. The bundler excludes unrelated or
stale SDK outputs and fails when either expected package is missing. The main
release waits for all architectures before uploading these bundles alongside the
other platform packages. Stable bundles also reach the existing versioned MinIO
download directory.

## Use

Install `iping-mihomo`, `iping`, and their dependencies. Installation enables and
starts `/etc/init.d/iping`. Open `http://<router-LAN-address>:19091/` and enter the
Web access key printed over SSH by:

```sh
/usr/libexec/iping/agent token
```

The key is created on first use and stored privately in `/etc/iping/web-key`.
Successful authorization creates a signed HttpOnly, SameSite Strict browser
cookie valid for twelve hours. The HTTP server accepts private, loopback, and
link-local clients; state-changing API calls also require the same Origin.

After authorizing the router, sign in to the iPing account in the Web interface.
Browser login uses a one-time code, state, and PKCE verifier; pending login is
bound to the authorized browser session. Allow its login popup. The account
session and subscription credentials stay in the Agent's private data directory.
The account login and the router access key serve different purposes.

Sync downloads and validates the subscription before installing it. Connect
starts the private Core; disconnect stops that process and releases its network
resources. The enabled intent persists across reboot. The Agent and Web page
remain available while disconnected.

The optional UCI settings are:

```text
config iping 'config'
    option site 'https://iping.my'
    option enabled '0'
    option web_listen '0.0.0.0:19091'
```

Changing the site or Web listener requires `/etc/init.d/iping restart`. Core
settings are edited in the Web interface, rather than UCI. The local root-only
Unix socket also exposes the API through `/usr/libexec/iping/agent call METHOD`
with a JSON request on stdin.

## Configuration And Ownership

`/etc/iping/` contains the account session, original subscription `source.yaml`,
local overrides `settings.json`, validated `profile.yaml`, and private controller
and Web keys. `/var/run/iping/` contains the running profile, job state, bounded
Core log, process locks, Unix socket, and network lease. The package preserves
its own data across sysupgrade; no older plugin configuration is migrated.

General, advanced, custom resource, DNS, and TUN controls share the application's
settings contract. Resettable DNS/TUN fields follow the subscription after their
local override is removed. TUN enable/device and DNS enable/listen are router-owned
settings with explicit defaults. The Agent validates all changes with Mihomo
before replacing files; a failed running reconfiguration restores the previous
files and Core. Proxy modes can be saved while disconnected; live update failures
restore the previous local settings. Telemetry is decoded into the shared typed
snapshots, and both platforms use the same traffic cards and node-selection policy.

Custom nodes use the same structured editor as native clients, including credentials,
transport/TLS options, secret visibility and nested value lists. Rule providers share
the name/URL form; the router also selects behavior and source format. Catalog edits
use the shared resource controller for validation, ordering, deletion, acknowledged
saves and retry after failure. IDs are strings so browser numbers cannot truncate
native database IDs. Nodes are stored as `{id, definition, emptyOptions}` objects and remote rule
providers as `{id, label, url, behavior, format}`; older YAML-list values are not
imported. Native file imports and rule-set compilation remain native capabilities.

Saving a node, provider, filter, rule or script adds it to the resource library. The
"Apply resources" page explicitly selects what the current profile uses. Selection
is stored per native profile and per router account; an edit carries its profile
identity so switching profiles/accounts cannot redirect a pending save. Unselected
library changes do not alter the running router profile or restart Core.

Rules use `{id, definition}` with the shared structured Rule fields, preserving
comma-containing and regular-expression payloads. Scripts use `{id, label, content}`
with an optional source `url`. Both platforms share their default editors and list
operations; the native advanced code editor and file/URL imports remain available.
The selected script transforms the source first, followed by selected resources and
prepended rules, then platform network/security settings. A rule target of `MATCH`
resolves to the source's final MATCH target. Conflicting source/resource names fail
validation. Old raw rule lists and the single-script setting are not imported.

The filter catalog uses the shared native/Web list and form, with backend validation
and save completion. `custom.filters` is an ordered list of `{label, regex}` objects;
previous map-shaped values are not imported. Patterns use the same regexp2 syntax
and backtick-separated alternatives as native validation. On both platforms, selected
filters create selector groups with Mihomo's live proxy/provider filtering. The
Web "Group icons" page edits group-to-icon assignments. Native "Icon sets" manages
an icon library and is a distinct backend capability.

The Agent reserves the loopback controller `127.0.0.1:19090`, TUN device `iping0`
(by default), route table 39200, rule priorities 9200–9210 and 39200, and marks
0x4950/0x4951. It enforces auto-route/auto-redirect and blocks alternate TUN
listeners and controller endpoints from subscription scripts. Startup rejects
pre-existing conflicting resources. Core readiness requires both an authenticated
controller and, when TUN is enabled, the expected interface and nftables table.
Network leases record resource identities so stale cleanup refuses resources
replaced by another process. Running another transparent proxy concurrently is
not supported by the shared Mihomo nftables table.

procd supervises the Agent; the Agent owns the Core's exact child process and
serializes lifecycle transitions. Linux parent-death signaling terminates the
Core if the Agent crashes. Unexpected Core exit retries the desired running state.
A service restart closes jobs and the owned Core before procd starts a replacement.

## Verification

```sh
flutter pub get
flutter analyze --no-fatal-infos
cd openwrt/ui
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

From `openwrt/iping/src`, `go test ./...` checks compilation of the embedded Agent;
the Web build must exist before packaging. Validate SDK builds for every release
target. Real router acceptance should cover LAN traffic and DNS, IPv4/IPv6,
firewall reload, reboot, Core/Agent failure recovery, subscription updates, and
settings rollback. A desktop or container build alone does not establish those
hardware behaviors.
