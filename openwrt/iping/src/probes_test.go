package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/relayx-org/FlClash/openwrt/iping/probe"
)

func probeFixture(t *testing.T) (*app, *atomic.Value, *atomic.Value) {
	t.Helper()
	dir := t.TempDir()
	a := &app{dataDir: dir, runDir: dir, runProfile: filepath.Join(dir, "config.yaml"), site: "https://example.com", ctx: context.Background(), client: &http.Client{Timeout: time.Second}}
	a.core = &coreRuntime{app: a}
	if err := writeJSON(filepath.Join(dir, "session.json"), credentials{ID: 1, Email: "user@example.com", SubscriptionToken: "subscription", AccessKey: "11111111-1111-1111-1111-111111111111", Site: a.site}); err != nil {
		t.Fatal(err)
	}
	selected, mode := &atomic.Value{}, &atomic.Value{}
	selected.Store("node-a")
	mode.Store("rule")
	controller := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer control" {
			w.WriteHeader(401)
			return
		}
		switch r.URL.Path {
		case "/configs":
			json.NewEncoder(w).Encode(map[string]string{"mode": mode.Load().(string)})
		case "/proxies":
			json.NewEncoder(w).Encode(map[string]any{"proxies": map[string]any{"proxy": map[string]any{"all": []string{"node-a", "node-b"}, "now": selected.Load().(string)}}})
		default:
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(controller.Close)
	a.controllerAddress = strings.TrimPrefix(controller.URL, "http://")
	child := &coreChild{started: time.UnixMilli(1700000000000), done: make(chan struct{})}
	child.ready.Store(true)
	a.core.current.Store(child)
	if err := writePrivate(a.runProfile, []byte(fmt.Sprintf("external-controller: %s\nsecret: control\n", a.controllerAddress))); err != nil {
		t.Fatal(err)
	}
	return a, selected, mode
}

func withProbeProxy(t *testing.T, a *app, handler http.HandlerFunc) {
	t.Helper()
	proxy := httptest.NewServer(handler)
	t.Cleanup(proxy.Close)
	parsed, _ := url.Parse(proxy.URL)
	file, err := os.OpenFile(a.runProfile, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	fmt.Fprintf(file, "mixed-port: %s\nauthentication: ['probe:private']\n", parsed.Port())
}

func TestOutboundProbeUsesTheOwnedProxyAndItsAuthentication(t *testing.T) {
	a, _, _ := probeFixture(t)
	var calls atomic.Int32
	withProbeProxy(t, a, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		want := "Basic " + base64.StdEncoding.EncodeToString([]byte("probe:private"))
		if r.Header.Get("Proxy-Authorization") != want {
			t.Errorf("proxy authentication missing")
		}
		if r.Header.Get("Authorization") != "" {
			t.Errorf("controller credentials escaped to the probe")
		}
		if r.URL.Host != "does-not-resolve.invalid" {
			t.Errorf("unexpected probe destination %s", r.URL.Host)
		}
		fmt.Fprint(w, "ip=203.0.113.7\nloc=JP\n")
	})
	value, err := a.outboundIP(context.Background(), arguments{URLs: []string{"http://does-not-resolve.invalid/trace"}})
	if err != nil {
		t.Fatal(err)
	}
	result := value.(*probe.OutboundIpResult)
	if result.Error != "" || result.Body != "ip=203.0.113.7\nloc=JP\n" || result.CoreEpoch != 1700000000000 || result.PicksVersion == 0 {
		t.Fatalf("probe result = %+v", result)
	}
	if calls.Load() != 1 {
		t.Fatalf("proxy calls = %d", calls.Load())
	}
}

func TestSiteRequestsUseTheOwnedProxyWhileRunning(t *testing.T) {
	a, _, _ := probeFixture(t)
	a.site = "http://does-not-resolve.invalid"
	var calls atomic.Int32
	withProbeProxy(t, a, func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.URL.Host != "does-not-resolve.invalid" || r.Header.Get("Authorization") != "Bearer account-token" {
			t.Error("site request lost its destination or account authorization")
		}
		want := "Basic " + base64.StdEncoding.EncodeToString([]byte("probe:private"))
		if r.Header.Get("Proxy-Authorization") != want {
			t.Error("site proxy authentication missing")
		}
		fmt.Fprint(w, `{"id":1}`)
	})
	data, err := a.request(context.Background(), http.MethodGet, "/api/user/info", nil, "account-token", 1024)
	if err != nil || string(data) != `{"id":1}` || calls.Load() != 1 {
		t.Fatalf("proxied site request: %s, %v, calls %d", data, err, calls.Load())
	}
	a.core.current.Store(nil)
	direct := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "direct") }))
	defer direct.Close()
	a.site = direct.URL
	data, err = a.request(context.Background(), http.MethodGet, "/site", nil, "", 1024)
	if err != nil || string(data) != "direct" || calls.Load() != 1 {
		t.Fatalf("stopped site request: %s, %v", data, err)
	}
}

func TestStoppedCoreProbesTheDirectRoute(t *testing.T) {
	a, _, _ := probeFixture(t)
	a.core.current.Store(nil)
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, `{"ip":"203.0.113.8","country":"US"}`) }))
	defer target.Close()
	value, err := a.outboundIP(context.Background(), arguments{URLs: []string{target.URL}})
	if err != nil {
		t.Fatal(err)
	}
	result := value.(*probe.OutboundIpResult)
	if result.Error != "" || result.CoreEpoch != 0 {
		t.Fatalf("direct result = %+v", result)
	}
	route, err := a.probeRoute(context.Background())
	if err != nil || route.Proxied {
		t.Fatalf("direct route = %+v, %v", route, err)
	}
}

func TestRunningProbeNeverFallsBackWhenProxyPortsAreDisabled(t *testing.T) {
	a, _, _ := probeFixture(t)
	if _, err := a.outboundIP(context.Background(), arguments{URLs: []string{"https://ident.me/json"}}); err != failure("controller_unavailable") {
		t.Fatalf("error = %v", err)
	}
	if _, err := a.outboundIP(context.Background(), arguments{ProxyName: "node-a", URLs: []string{"https://ident.me/json"}}); err != failure("invalid_request") {
		t.Fatalf("pinned probe error = %v", err)
	}
}

func TestProbeRouteVersionsTrackSelectionsModesAndCoreReplacements(t *testing.T) {
	a, selected, mode := probeFixture(t)
	first, err := a.probeRoute(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	same, err := a.probeRoute(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if same.Version != first.Version {
		t.Fatal("unchanged route advanced")
	}
	selected.Store("node-b")
	changed, _ := a.probeRoute(context.Background())
	if changed.Version <= first.Version || changed.Picks["proxy"] != "node-b" {
		t.Fatalf("changed route = %+v", changed)
	}
	mode.Store("global")
	global, _ := a.probeRoute(context.Background())
	if global.Version <= changed.Version {
		t.Fatal("mode change did not invalidate probes")
	}
	child := &coreChild{started: time.UnixMilli(1700000001000), done: make(chan struct{})}
	child.ready.Store(true)
	a.core.current.Store(child)
	restarted, _ := a.probeRoute(context.Background())
	if restarted.Epoch == global.Epoch {
		t.Fatal("replacement Core kept the old epoch")
	}
}

func TestProbeCancellationReleasesTheProxyRequest(t *testing.T) {
	a, _, _ := probeFixture(t)
	started, cancelled := make(chan struct{}), make(chan struct{})
	withProbeProxy(t, a, func(w http.ResponseWriter, r *http.Request) { close(started); <-r.Context().Done(); close(cancelled) })
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		defer close(done)
		a.outboundIP(ctx, arguments{URLs: []string{"http://does-not-resolve.invalid/"}})
	}()
	<-started
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("cancelled probe did not finish")
	}
	select {
	case <-cancelled:
	case <-time.After(time.Second):
		t.Fatal("cancelled HTTP request kept running")
	}
}

func TestIpQualityPreservesSourceStatusAndRejectsOtherHosts(t *testing.T) {
	a, _, _ := probeFixture(t)
	withProbeProxy(t, a, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(429)
		fmt.Fprint(w, `{"error":"rate limited"}`)
	})
	value, err := a.ipQuality(context.Background(), "http://ident.me/json")
	if err != nil {
		t.Fatal(err)
	}
	result := value.(map[string]any)
	if result["status"] != 429 || result["body"] != `{"error":"rate limited"}` {
		t.Fatalf("source result = %+v", result)
	}
	if _, err := a.ipQuality(context.Background(), "http://127.0.0.1/private"); err != failure("invalid_request") {
		t.Fatalf("unexpected host error = %v", err)
	}
}

func TestConcurrentProbeRouteReadsKeepTheSameRevision(t *testing.T) {
	a, _, _ := probeFixture(t)
	var tasks sync.WaitGroup
	versions := make(chan uint64, 16)
	for range 16 {
		tasks.Add(1)
		go func() {
			defer tasks.Done()
			route, err := a.probeRoute(context.Background())
			if err != nil {
				t.Error(err)
				return
			}
			versions <- route.Version
		}()
	}
	tasks.Wait()
	close(versions)
	for version := range versions {
		if version != 1 {
			t.Fatalf("unchanged route revision = %d", version)
		}
	}
}
