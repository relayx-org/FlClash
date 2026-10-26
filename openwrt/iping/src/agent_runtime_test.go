package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"go.yaml.in/yaml/v3"
)

func TestCoreChild(t *testing.T) {
	if os.Getenv("IPING_TEST_CHILD") != "1" {
		return
	}
	path := ""
	validate := false
	for i, arg := range os.Args {
		if arg == "-t" {
			validate = true
		}
		if arg == "-f" && i+1 < len(os.Args) {
			path = os.Args[i+1]
		}
	}
	var cfg map[string]any
	data, err := os.ReadFile(path)
	if err != nil || yaml.Unmarshal(data, &cfg) != nil {
		os.Exit(3)
	}
	if validate {
		if cfg["fake-invalid"] == true {
			os.Exit(4)
		}
		return
	}
	if cfg["fake-start-fail"] == true {
		os.Exit(5)
	}
	if os.Getenv("IPING_TEST_DELAY") == "1" {
		time.Sleep(time.Second)
	}
	address, _ := cfg["external-controller"].(string)
	secret, _ := cfg["secret"].(string)
	server := &http.Server{Addr: address, Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+secret {
			w.WriteHeader(401)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/configs" {
			io.WriteString(w, `{"mode":"rule"}`)
		} else {
			io.WriteString(w, `{"version":"fixture"}`)
		}
	})}
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			os.Exit(6)
		}
	}()
	<-ctx.Done()
	server.Close()
}

type testAgent struct {
	a       *app
	enabled bool
	mu      sync.Mutex
}

func testSetup(t *testing.T, slow bool) *testAgent {
	t.Helper()
	dir := t.TempDir()
	ctx, cancel := context.WithCancel(context.Background())
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	listener.Close()
	f := &testAgent{}
	a := &app{dataDir: filepath.Join(dir, "data"), runDir: filepath.Join(dir, "run"), profile: filepath.Join(dir, "data/profile.yaml"), runProfile: filepath.Join(dir, "run/config.yaml"), controllerAddress: address, site: "https://example.com", client: &http.Client{Timeout: time.Second}, ctx: ctx}
	f.a = a
	a.core = &coreRuntime{app: a}
	for _, p := range []string{a.dataDir, a.runDir} {
		if err := os.MkdirAll(p, 0700); err != nil {
			t.Fatal(err)
		}
	}
	exe, _ := os.Executable()
	wrapper := filepath.Join(dir, "core")
	extra := ""
	if slow {
		extra = "IPING_TEST_DELAY=1 "
	}
	script := "#!/bin/sh\nexport IPING_TEST_CHILD=1\n" + "exec env " + extra + "'" + exe + "' -test.run='^TestCoreChild$' -- \"$@\"\n"
	if err := os.WriteFile(wrapper, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	a.coreBinary = wrapper
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if name == wrapper {
			return exec.CommandContext(ctx, name, args...).Output()
		}
		if name == "/sbin/uci" {
			f.mu.Lock()
			defer f.mu.Unlock()
			if len(args) > 1 && args[1] == "get" {
				if f.enabled {
					return []byte("1"), nil
				}
				return []byte("0"), nil
			}
			if len(args) > 1 && args[0] == "set" {
				f.enabled = strings.HasSuffix(args[1], "=1")
			}
			return nil, nil
		}
		return nil, fmt.Errorf("unexpected command %s %v", name, args)
	}
	if err := writeJSON(filepath.Join(a.dataDir, "session.json"), credentials{ID: 1, Email: "user@example.com", SubscriptionToken: "subscription", AccessKey: "11111111-1111-1111-1111-111111111111", Site: a.site}); err != nil {
		t.Fatal(err)
	}
	source := []byte("proxies:\n- {name: fixture, type: direct}\nrules: [MATCH,DIRECT]\n")
	writePrivate(filepath.Join(a.dataDir, "source.yaml"), source)
	data, err := a.buildProfile(source, map[string]any{"tun.enable": false})
	if err != nil {
		t.Fatal(err)
	}
	if err := writePrivate(a.profile, data); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		cancel()
		if err := a.core.close(); err != nil {
			t.Error(err)
		}
		a.jobs.Wait()
	})
	return f
}

func waitUntil(t *testing.T, test func() bool) {
	t.Helper()
	deadline := time.Now().Add(8 * time.Second)
	for !test() {
		if time.Now().After(deadline) {
			t.Fatal("condition timed out")
		}
		time.Sleep(20 * time.Millisecond)
	}
}

func TestRuntimeStartStopAndLatestIntent(t *testing.T) {
	f := testSetup(t, true)
	a := f.a
	result := make(chan error, 1)
	go func() { result <- a.core.setRunning(a.ctx, true) }()
	waitUntil(t, func() bool { return a.core.current.Load() != nil })
	child := a.core.current.Load()
	if err := a.core.setRunning(a.ctx, false); err != nil {
		t.Fatal(err)
	}
	if err := <-result; err == nil {
		t.Fatal("superseded start reported applied")
	}
	if a.core.running() || a.core.current.Load() != nil {
		t.Fatal("late start survived stop")
	}
	select {
	case <-child.done:
	default:
		t.Fatal("owned child was not reaped")
	}
	if err := a.core.setRunning(a.ctx, true); err != nil {
		t.Fatal(err)
	}
	if !a.core.running() {
		t.Fatal("core not ready")
	}
	if err := a.core.close(); err != nil {
		t.Fatal(err)
	}
	if err := a.core.setRunning(a.ctx, true); err == nil {
		t.Fatal("terminal runtime accepted a start")
	}
}

func TestFailedReplacementRestoresFilesAndRunningCore(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	if err := a.core.setRunning(a.ctx, true); err != nil {
		t.Fatal(err)
	}
	original, err := os.ReadFile(a.profile)
	if err != nil {
		t.Fatal(err)
	}
	bad := append(append([]byte(nil), original...), []byte("\nfake-start-fail: true\n")...)
	settings := filepath.Join(a.dataDir, "settings.json")
	if err := a.replaceProfile(a.ctx, map[string][]byte{a.profile: bad, settings: []byte(`{"ipv6":true}`)}, true); err == nil {
		t.Fatal("failed candidate accepted")
	}
	restored, _ := os.ReadFile(a.profile)
	if !bytes.Equal(original, restored) {
		t.Fatal("profile was not restored")
	}
	if _, err := os.Stat(settings); !os.IsNotExist(err) {
		t.Fatal("new settings survived rollback")
	}
	if !a.core.running() {
		t.Fatal("old core was not restored")
	}
}

func TestUnexpectedChildExitConvergesWithoutLeakingOwnership(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	if err := a.core.setRunning(a.ctx, true); err != nil {
		t.Fatal(err)
	}
	first := a.core.current.Load()
	if err := first.cmd.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	waitUntil(t, func() bool { return a.core.running() && a.core.current.Load() != first })
	if err := a.core.setRunning(a.ctx, false); err != nil {
		t.Fatal(err)
	}
	if a.core.current.Load() != nil {
		t.Fatal("child lease retained after stop")
	}
}

func TestUnauthenticatedControllerCannotMasqueradeAsOwnedCore(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, `{"version":"foreign"}`) }))
	defer server.Close()
	a.controllerAddress = strings.TrimPrefix(server.URL, "http://")
	raw, _ := os.ReadFile(a.profile)
	var config map[string]any
	yaml.Unmarshal(raw, &config)
	config["external-controller"] = a.controllerAddress
	raw, _ = yaml.Marshal(config)
	writePrivate(a.runProfile, raw)
	if err := a.controllerReady(a.ctx); err == nil {
		t.Fatal("foreign unauthenticated API accepted")
	}
}

func TestDelayProxyKeepsNodeFailuresSeparateFromControllerFailures(t *testing.T) {
	for _, tc := range []struct {
		status int
		delay  int
	}{
		{http.StatusOK, 42},
		{http.StatusGatewayTimeout, -1},
		{http.StatusServiceUnavailable, -2},
		{http.StatusUnauthorized, 0},
		{http.StatusNotFound, 0},
	} {
		t.Run(strconv.Itoa(tc.status), func(t *testing.T) {
			a := testSetup(t, false).a
			if err := a.core.setRunning(a.ctx, true); err != nil {
				t.Fatal(err)
			}
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/proxies/Node A/delay" || r.URL.Query().Get("timeout") != "5000" || r.Header.Get("Authorization") != "Bearer private" {
					t.Errorf("unexpected controller request: %s", r.URL)
				}
				w.WriteHeader(tc.status)
				io.WriteString(w, `{"delay":42}`)
			}))
			defer server.Close()
			config, _ := yaml.Marshal(map[string]any{"external-controller": strings.TrimPrefix(server.URL, "http://"), "secret": "private"})
			if err := writePrivate(a.runProfile, config); err != nil {
				t.Fatal(err)
			}
			result, err := a.delayProxy(a.ctx, "Node A")
			if tc.delay == 0 {
				if !errors.Is(err, failure("controller_unavailable")) {
					t.Fatalf("controller failure = %v", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			raw, _ := json.Marshal(result)
			var value struct {
				Delay int `json:"delay"`
			}
			if json.Unmarshal(raw, &value) != nil || value.Delay != tc.delay {
				t.Fatalf("delay response = %s, want %d", raw, tc.delay)
			}
			if !a.running(a.ctx) {
				t.Fatal("delay test changed the Core lifecycle")
			}
		})
	}
}

func TestDashboardUsesAppliedProfileAndKeepsSettingsPrivate(t *testing.T) {
	a := testSetup(t, false).a
	command := a.command
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if name == "/sbin/uci" && len(args) == 3 && args[2] == "network.lan.ipaddr" {
			return []byte("192.168.1.1/24\n"), nil
		}
		return command(ctx, name, args...)
	}
	if err := writePrivate(a.profile, []byte("proxy-groups: [{name: proxy}]\nproxies: [{name: one}, {name: two}]\nrules: [MATCH,DIRECT]\n")); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []dashboardCounts{{1, 2, 2}, {0, 1, 1}} {
		result, err := a.dashboard(a.ctx)
		if err != nil {
			t.Fatal(err)
		}
		data := result.(map[string]any)
		if data["local_ip"] != "192.168.1.1" || data["counts"] != expected {
			t.Fatalf("dashboard data = %v", data)
		}
		if len(data["settings"].(map[string]any)) != 3 {
			t.Fatal("dashboard exposed unrelated settings")
		}
		if err := writePrivate(a.profile, []byte("proxies: [{name: changed}]\nrules: ['MATCH,DIRECT']\n")); err != nil {
			t.Fatal(err)
		}
	}
}

func TestConflictingNetworkIsNeverCleanedWithoutALease(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	deleted := false
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if strings.Contains(strings.Join(args, " "), "delete") {
			deleted = true
		}
		if name == "nft" {
			return []byte(`{"nftables":[{"table":{"family":"inet","name":"mihomo","handle":17}}]}`), nil
		}
		if name == "ip" {
			return []byte(`[]`), nil
		}
		return nil, errors.New("unexpected command")
	}
	if err := a.acquireNetwork(a.ctx, "iping0"); err == nil || err.Error() != "service_conflict" {
		t.Fatalf("conflict result %v", err)
	}
	if deleted {
		t.Fatal("foreign network resources were removed")
	}
	if _, err := os.Stat(filepath.Join(a.runDir, "network.json")); !os.IsNotExist(err) {
		t.Fatal("conflicting network was claimed")
	}
}

func TestWebAccessNeedsNoOwnerKeyAndKeepsLoginBrowserBound(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	server := httptest.NewServer(a.webHandler())
	defer server.Close()
	request := func(path, origin, body string, cookie *http.Cookie) (*http.Response, map[string]any) {
		req, _ := http.NewRequest("POST", server.URL+path, strings.NewReader(body))
		req.Header.Set("Origin", origin)
		if cookie != nil {
			req.AddCookie(cookie)
		}
		resp, err := server.Client().Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		var result map[string]any
		if json.NewDecoder(resp.Body).Decode(&result) != nil {
			t.Fatal("invalid JSON response")
		}
		return resp, result
	}
	response, result := request("/api/status", server.URL, `{}`, nil)
	if response.StatusCode != 200 || result["ok"] != true {
		t.Fatal("local API still requires a router access key")
	}
	cookies := response.Cookies()
	if len(cookies) != 1 || !cookies[0].HttpOnly || cookies[0].SameSite != http.SameSiteStrictMode || !sessionID.MatchString(cookies[0].Value) {
		t.Fatal("missing browser session for account login")
	}
	cookie := cookies[0]
	if response, result := request("/api/status", server.URL, `{}`, cookie); response.StatusCode != 200 || result["ok"] != true || len(response.Cookies()) != 0 {
		t.Fatal("browser session was not reused")
	}
	if response, _ := request("/api/session", server.URL, `{}`, nil); response.StatusCode != 404 {
		t.Fatal("removed access-key endpoint is still available")
	}
	for _, origin := range []string{"http://evil.test", ""} {
		if response, _ := request("/api/status", origin, `{}`, cookie); response.StatusCode != 403 {
			t.Fatal("cross-origin mutation accepted")
		}
	}
	if _, err := os.Stat(filepath.Join(a.dataDir, "web-key")); !os.IsNotExist(err) {
		t.Fatal("router access key was created")
	}
	req := httptest.NewRequest("GET", "http://router/", nil)
	req.RemoteAddr = "203.0.113.1:1234"
	req.Header.Set("X-Forwarded-For", "127.0.0.1")
	recorder := httptest.NewRecorder()
	a.webHandler().ServeHTTP(recorder, req)
	if recorder.Code != 403 {
		t.Fatal("public client was accepted")
	}
}

func TestProfileOwnsControllerAndRoutingAndKeepsExplicitEmptyOverrides(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	source := []byte("external-controller: 0.0.0.0:9999\nexternal-controller-unix: /tmp/foreign\nsecret: untrusted\ntun: {enable: false, device: foreign, auto-route: false, file-descriptor: 3}\n")
	data, err := a.buildProfile(source, map[string]any{"dns.fallback": []any{}, "dns.ipv6": false})
	if err != nil {
		t.Fatal(err)
	}
	var profile map[string]any
	yaml.Unmarshal(data, &profile)
	if profile["external-controller"] != a.controllerAddress || profile["secret"] == "untrusted" || profile["external-controller-unix"] != nil {
		t.Fatal("untrusted controller survived")
	}
	if yamlSetting(profile, "tun.enable") != true || yamlSetting(profile, "tun.device") != "iping0" || yamlSetting(profile, "tun.auto-route") != true || yamlSetting(profile, "tun.file-descriptor") != nil {
		t.Fatal("routing ownership lost")
	}
	if value := yamlSetting(profile, "dns.fallback"); value == nil || len(value.([]any)) != 0 {
		t.Fatal("empty DNS override lost")
	}
	if err := validateSettings(map[string]any{"tun.enable": nil}); err == nil {
		t.Fatal("owned switch accepted profile inheritance")
	}
}

func TestStaleLeaseRefusesReplacedResources(t *testing.T) {
	for _, table := range []uint64{0, 17} {
		t.Run(strconv.FormatUint(table, 10), func(t *testing.T) {
			f := testSetup(t, false)
			a := f.a
			path := filepath.Join(a.runDir, "network.json")
			if err := writeJSON(path, networkLease{Device: "iping0", IfIndex: 4, TableHandle: table}); err != nil {
				t.Fatal(err)
			}
			mutated := false
			a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
				text := strings.Join(args, " ")
				if strings.Contains(text, "delete") || strings.Contains(text, " del ") || strings.Contains(text, "flush") {
					mutated = true
				}
				if name == "nft" {
					return []byte(`{"nftables":[{"table":{"family":"inet","name":"mihomo","handle":18}}]}`), nil
				}
				if name == "ip" {
					return []byte(`[{"ifname":"iping0","ifindex":5}]`), nil
				}
				return nil, errors.New("unexpected command")
			}
			if err := a.cleanNetwork(a.ctx); err == nil || err.Error() != "service_conflict" {
				t.Fatalf("cleanup %v", err)
			}
			if mutated {
				t.Fatal("replaced resource mutated")
			}
			if _, err := os.Stat(path); err != nil {
				t.Fatal("lease lost", err)
			}
		})
	}
}

func TestBackgroundJobReleasesMutationLockAfterStartingChild(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	if err := writeJSON(filepath.Join(a.dataDir, "settings.json"), map[string]any{"tun.enable": false}); err != nil {
		t.Fatal(err)
	}
	lock, err := a.lock()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := a.startJob("connect", lock); err != nil {
		t.Fatal(err)
	}
	lock.Close()
	a.jobs.Wait()
	var job jobInfo
	if err := readJSON(filepath.Join(a.runDir, "job.json"), &job); err != nil {
		t.Fatal(err)
	}
	if job.Error != "" {
		t.Fatal(job.Error)
	}
	next, err := a.lock()
	if err != nil {
		t.Fatal("child retained mutation lock", err)
	}
	next.Close()
}

func TestOfflineTelemetryAndModePersistence(t *testing.T) {
	f := testSetup(t, false)
	a := f.a
	source := []byte("mode: direct\nproxies: [{name: fixture, type: direct}]\nrules: ['MATCH,DIRECT']\n")
	if err := writePrivate(filepath.Join(a.dataDir, "source.yaml"), source); err != nil {
		t.Fatal(err)
	}
	raw, err := a.telemetry(a.ctx)
	if err != nil {
		t.Fatal(err)
	}
	data := raw.(map[string]any)
	if data["running"] != false || data["mode"] != "direct" || data["connections"] != 0 {
		t.Fatal(data)
	}
	if err := a.setMode(a.ctx, "global"); err != nil {
		t.Fatal(err)
	}
	raw, err = a.telemetry(a.ctx)
	if err != nil {
		t.Fatal(err)
	}
	if raw.(map[string]any)["mode"] != "global" {
		t.Fatal(raw)
	}
	if err := a.setMode(a.ctx, "invalid"); err == nil {
		t.Fatal("invalid mode accepted")
	}
}

func TestLiveModeRequestFailureRestoresSettings(t *testing.T) {
	for _, exists := range []bool{false, true} {
		t.Run(fmt.Sprint(exists), func(t *testing.T) {
			f := testSetup(t, false)
			a := f.a
			if err := a.core.setRunning(a.ctx, true); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(a.dataDir, "settings.json")
			previous := []byte(`{"mode":"direct","tun.enable":false}`)
			if exists {
				if err := writePrivate(path, previous); err != nil {
					t.Fatal(err)
				}
			}
			ctx, cancel := context.WithCancel(a.ctx)
			cancel()
			if err := a.setMode(ctx, "global"); err == nil {
				t.Fatal("failed controller accepted")
			}
			data, err := os.ReadFile(path)
			if exists {
				if err != nil || !bytes.Equal(data, previous) {
					t.Fatalf("settings changed: %s %v", data, err)
				}
			} else if !os.IsNotExist(err) {
				t.Fatal("new settings remained", err)
			}
		})
	}
}

func TestSharedFilterLanguageAndOrder(t *testing.T) {
	errors, err := validateResourceFilters([]string{`(?<=hk)1`, "hk`jp", "hk`(jp", `\p{Han}`})
	if err != nil || errors[0] != "" || errors[1] != "" || errors[2] == "" || errors[3] != "" {
		t.Fatal(errors, err)
	}
	values := map[string]any{"custom.bindings": testBindings(nil, nil, []any{"Z", "A"}, nil, nil), "custom.filters": []any{
		map[string]any{"label": "Z", "regex": "(?<=hk)1`jp"},
		map[string]any{"label": "A", "regex": "us"},
	}}
	source := []byte("proxies: [{name: hk1, type: direct}, {name: jp2, type: direct}, {name: us3, type: direct}]\nproxy-groups: [{name: PROXY, type: select, proxies: [hk1]}]\nrules: ['MATCH,DIRECT']\n")
	data, err := applyProfileSettings(source, values)
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]any
	if err := yaml.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	groups := config["proxy-groups"].([]any)
	if len(groups) != 3 || groups[1].(map[string]any)["name"] != "Z" || groups[2].(map[string]any)["name"] != "A" {
		t.Fatal(groups)
	}
	filter := groups[1].(map[string]any)
	if filter["filter"] != "(?<=hk)1`jp" || filter["include-all-proxies"] != true || filter["include-all-providers"] != true {
		t.Fatal(filter)
	}
	if err := validateSettings(values); err != nil {
		t.Fatal(err)
	}
	values["custom.filters"].([]any)[1] = map[string]any{"label": "Z", "regex": "us"}
	if err := validateSettings(values); err == nil {
		t.Fatal("duplicate labels accepted")
	}
	values["custom.filters"] = map[string]any{"old": "us"}
	if err := validateSettings(values); err == nil {
		t.Fatal("map accepted as ordered filters")
	}
}

func TestSharedResourceCatalog(t *testing.T) {
	proxies := []any{map[string]any{"id": "browser-id", "definition": map[string]any{"name": "Home", "type": "direct"}}}
	providers := []any{map[string]any{"id": "large-12345678901234567890", "label": "Ads", "url": "https://example.com/ads.yaml", "behavior": "domain", "format": "yaml"}}
	values := map[string]any{"custom.proxies": proxies, "custom.rule-providers": providers, "custom.bindings": testBindings([]any{"browser-id"}, []any{"large-12345678901234567890"}, nil, nil, nil)}
	if err := validateSettings(values); err != nil {
		t.Fatal(err)
	}
	source := []byte("proxies: [{name: fixture, type: direct}]\nproxy-groups: [{name: PROXY, type: select, proxies: [fixture]}]\nrules: ['MATCH,DIRECT']\n")
	data, err := applyProfileSettings(source, values)
	if err != nil {
		t.Fatal(err)
	}
	var config map[string]any
	if err := yaml.Unmarshal(data, &config); err != nil {
		t.Fatal(err)
	}
	if len(config["proxies"].([]any)) != 2 {
		t.Fatal(config)
	}
	if fmt.Sprint(config["proxy-groups"].([]any)[0].(map[string]any)["proxies"]) != "[fixture Home]" {
		t.Fatal(config)
	}
	provider := config["rule-providers"].(map[string]any)["Ads"].(map[string]any)
	if provider["type"] != "http" || provider["url"] != "https://example.com/ads.yaml" || strings.Contains(provider["path"].(string), "large-") {
		t.Fatal(provider)
	}
	for _, bad := range []any{[]any{"{name: old, type: direct}"}, append(proxies, proxies[0]), []any{map[string]any{"id": "x", "definition": map[string]any{"name": "DIRECT", "type": "direct"}}}} {
		if _, err := resourceProxies(bad); err == nil {
			t.Fatal("invalid proxies accepted", bad)
		}
	}
	for _, address := range []string{"file:///etc/shadow", "https://user:pass@example.com/a", "https://example.com/a#fragment", "https:///a"} {
		bad := map[string]any{"id": "x", "label": "Ads", "url": address, "behavior": "domain", "format": "yaml"}
		if _, err := resourceProviders([]any{bad}); err == nil {
			t.Fatal("invalid provider accepted", address)
		}
	}
	for _, format := range []string{"bad", "mrs"} {
		bad := map[string]any{"id": "x", "label": "Ads", "url": "https://example.com/a", "behavior": "classical", "format": format}
		if _, err := resourceProviders([]any{bad}); err == nil {
			t.Fatal("invalid format accepted", format)
		}
	}
}

func TestProxyValidationDoesNotStartCore(t *testing.T) {
	fixture := testSetup(t, false)
	a := fixture.a
	results, err := a.call(context.Background(), "validate_proxies", arguments{Proxies: []map[string]any{{"name": "Home", "type": "direct"}}})
	if err != nil || fmt.Sprint(results) != "[]" {
		t.Fatal(results, err)
	}
	if a.running(context.Background()) {
		t.Fatal("validation started Core")
	}
	original := a.command
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if name == a.coreBinary {
			return nil, errors.New("invalid proxy")
		}
		return original(ctx, name, args...)
	}
	results, err = a.call(context.Background(), "validate_proxies", arguments{Proxies: []map[string]any{{"name": "Home", "type": "not-supported"}}})
	if err != nil || fmt.Sprint(results) != "[invalid_proxy]" {
		t.Fatal(results, err)
	}
	matches, _ := filepath.Glob(filepath.Join(a.runDir, "validate-*"))
	if len(matches) != 0 {
		t.Fatal("validation files leaked", matches)
	}
}

func TestProxySearchAndTimeoutPolicy(t *testing.T) {
	proxies := map[string]proxyData{}
	if err := json.Unmarshal([]byte(`{"HK One":{"type":"Shadowsocks","history":[{"delay":-1}]},"HK Two":{"type":"VLESS","history":[{"delay":-1}]}}`), &proxies); err != nil {
		t.Fatal(err)
	}
	names := []string{"HK One", "HK Two"}
	if got := filteredProxyNames(names, proxies, arguments{Query: "hk SHADOWSOCKS", HideTimeout: true}); fmt.Sprint(got) != "[HK One]" {
		t.Fatal(got)
	}
	if got := filteredProxyNames(names, proxies, arguments{HideTimeout: true}); len(got) != 2 {
		t.Fatal("all timeout nodes disappeared", got)
	}
	if err := json.Unmarshal([]byte(`{"HK One":{"type":"Shadowsocks","history":[{"delay":-1}]},"HK Two":{"type":"VLESS","history":[{"delay":20}]}}`), &proxies); err != nil {
		t.Fatal(err)
	}
	if got := filteredProxyNames(names, proxies, arguments{HideTimeout: true}); fmt.Sprint(got) != "[HK Two]" {
		t.Fatal(got)
	}
}

func TestProxyModeVisibility(t *testing.T) {
	for _, test := range []struct {
		mode, name             string
		hidden, declared, want bool
	}{
		{"direct", "PROXY", false, false, false},
		{"global", "Hidden", true, false, true},
		{"rule", "Hidden", true, false, false},
		{"rule", "GLOBAL", false, false, false},
		{"rule", "GLOBAL", false, true, true},
		{"rule", "PROXY", false, false, true},
	} {
		if got := proxyGroupVisible(test.mode, test.name, test.hidden, test.declared); got != test.want {
			t.Fatal(test, got)
		}
	}
}

func TestEmptyProxyOptions(t *testing.T) {
	item := map[string]any{"id": "x", "definition": map[string]any{"name": "X", "type": "direct"}, "emptyOptions": []any{"alpn"}}
	values := map[string]any{"custom.proxies": []any{item}}
	if err := validateSettings(values); err != nil {
		t.Fatal(err)
	}
	for _, options := range []any{[]any{"unknown"}, []any{"alpn", "alpn"}, "alpn"} {
		item["emptyOptions"] = options
		if err := validateSettings(values); err == nil {
			t.Fatal("bad options accepted", options)
		}
	}
}

func testBindings(proxies, providers, filters, rules []any, script any) map[string]any {
	result := map[string]any{"script": script}
	for key, values := range map[string][]any{"proxies": proxies, "providers": providers, "filters": filters, "rules": rules} {
		if values == nil {
			values = []any{}
		}
		result[key] = values
	}
	return result
}

func TestResourceBindingsAreScopedToTheAccount(t *testing.T) {
	a := testSetup(t, false).a
	values := map[string]any{"custom.bindings": testBindings([]any{"one"}, nil, nil, nil, nil), "mode": "direct"}
	encoded, err := a.encodeProfileSettings(values)
	if err != nil {
		t.Fatal(err)
	}
	if err := writePrivate(filepath.Join(a.dataDir, "settings.json"), encoded); err != nil {
		t.Fatal(err)
	}
	account, _ := a.account()
	account.ID = 2
	if err := writeJSON(filepath.Join(a.dataDir, "session.json"), account); err != nil {
		t.Fatal(err)
	}
	got, err := a.profileSettings()
	if err != nil || got["custom.bindings"] != nil || got["mode"] != "direct" {
		t.Fatal(got, err)
	}
	account.ID = 1
	writeJSON(filepath.Join(a.dataDir, "session.json"), account)
	if err := a.setMode(context.Background(), "global"); err != nil {
		t.Fatal(err)
	}
	got, err = a.profileSettings()
	bindings, parseError := parseResourceBindings(got["custom.bindings"])
	if err != nil || parseError != nil || !bindings.Proxies["one"] {
		t.Fatal(got, err, parseError)
	}
	if _, err := a.call(context.Background(), "settings_set", arguments{ProfileID: "wrong", Changes: map[string]any{"mode": "rule"}}); err == nil || err.Error() != "resource_changed" {
		t.Fatal(err)
	}
}

func TestLibraryEditsDoNotApplyUnselectedResources(t *testing.T) {
	a := testSetup(t, false).a
	values := map[string]any{"tun.enable": false, "custom.proxies": []any{map[string]any{"id": "unused", "definition": map[string]any{"name": "Home", "type": "direct"}}}}
	source, _ := os.ReadFile(filepath.Join(a.dataDir, "source.yaml"))
	base, err := a.buildProfile(source, map[string]any{"tun.enable": false})
	if err != nil {
		t.Fatal(err)
	}
	candidate, err := a.buildProfile(source, values)
	if err != nil || !bytes.Equal(base, candidate) {
		t.Fatal("unused catalog changed profile", err)
	}
	if err := a.core.setRunning(context.Background(), true); err != nil {
		t.Fatal(err)
	}
	a.core.mu.Lock()
	child := a.core.current.Load()
	a.core.mu.Unlock()
	if err := writeJSON(filepath.Join(a.runDir, "settings-job.json"), values); err != nil {
		t.Fatal(err)
	}
	if err := a.applySettings(context.Background()); err != nil {
		t.Fatal(err)
	}
	a.core.mu.Lock()
	same := a.core.current.Load() == child
	a.core.mu.Unlock()
	if !same {
		t.Fatal("library write restarted Core")
	}
}

func TestSharedProfileExtensionContract(t *testing.T) {
	data, err := os.ReadFile("../../../test/fixtures/iping_profile_resources.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct{ Source, Values, Expected map[string]any }
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	source, _ := yaml.Marshal(fixture.Source)
	encoded, err := applyProfileSettings(source, fixture.Values)
	if err != nil {
		t.Fatal(err)
	}
	var actual map[string]any
	if err := yaml.Unmarshal(encoded, &actual); err != nil {
		t.Fatal(err)
	}
	got, _ := json.Marshal(actual)
	want, _ := json.Marshal(fixture.Expected)
	if !bytes.Equal(got, want) {
		t.Fatalf("got %s\nwant %s", got, want)
	}
	fixture.Values["custom.bindings"] = testBindings(nil, nil, nil, nil, nil)
	encoded, err = applyProfileSettings(source, fixture.Values)
	yaml.Unmarshal(encoded, &actual)
	if err != nil || len(actual["proxies"].([]any)) != 1 || len(actual["rules"].([]any)) != 1 {
		t.Fatal(actual, err)
	}
}

func TestExplicitBindingsRejectMissingCatalogEntries(t *testing.T) {
	for _, key := range []string{"proxies", "providers", "filters", "rules", "script"} {
		t.Run(key, func(t *testing.T) {
			bindings := testBindings(nil, nil, nil, nil, nil)
			if key == "script" {
				bindings[key] = "gone"
			} else {
				bindings[key] = []any{"gone"}
			}
			if err := validateBoundResources(map[string]any{"custom.bindings": bindings}); err == nil || err.Error() != "resource_changed" {
				t.Fatal(err)
			}
		})
	}
	if _, err := parseResourceBindings(map[string]any{"proxies": []any{}, "providers": []any{}, "filters": []any{}, "rules": []any{}, "unknown": nil}); err == nil {
		t.Fatal("unknown binding field accepted")
	}
}
