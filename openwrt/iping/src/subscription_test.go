package main

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

const manualProfile = "proxies:\n- {name: manual, type: direct}\nrules: [MATCH,DIRECT]\n"

func importForTest(t *testing.T, a *app, target string) string {
	t.Helper()
	if _, err := a.call(context.Background(), "import_subscription", arguments{URL: target}); err != nil {
		t.Fatal(err)
	}
	a.jobs.Wait()
	var job jobInfo
	if err := readJSON(filepath.Join(a.runDir, "job.json"), &job); err != nil || !job.Done {
		t.Fatalf("unfinished import: %+v %v", job, err)
	}
	return job.Error
}

func TestManualSubscriptionWithoutAccount(t *testing.T) {
	a := testSetup(t, false).a
	os.Remove(filepath.Join(a.dataDir, "session.json"))
	writeJSON(filepath.Join(a.dataDir, "settings.json"), map[string]any{"tun.enable": false})
	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		if r.Header.Get("Authorization") != "" || !strings.Contains(r.Header.Get("User-Agent"), "Clash") {
			t.Error("subscription request must be anonymous and advertise Clash format")
		}
		if r.URL.Path == "/redirect" {
			http.Redirect(w, r, "/sub?token=manual", http.StatusFound)
			return
		}
		io.WriteString(w, manualProfile)
	}))
	defer server.Close()
	a.client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	target := server.URL + "/redirect"
	if err := importForTest(t, a, "  "+target+"  "); err != "" {
		t.Fatal(err)
	}
	if _, err := a.account(); !errors.Is(err, failure("not_logged_in")) {
		t.Fatalf("manual import acquired an account: %v", err)
	}
	if value, err := a.subscriptionURL(); err != nil || value != target {
		t.Fatalf("subscription link not saved: %q %v", value, err)
	}
	status, _ := a.status(context.Background())
	if value := status.(map[string]any); value["logged_in"] != false || value["manual_subscription"] != true || value["nodes"] != 1 {
		t.Fatalf("unexpected manual status: %+v", value)
	}
	id, err := a.resourceProfileID()
	if err != nil || !strings.HasPrefix(id, "manual/") || strings.Contains(id, target) {
		t.Fatalf("invalid manual profile identity: %q %v", id, err)
	}
	for _, method := range []string{"settings_get", "dashboard", "logs", "probe_route"} {
		if _, err := a.call(context.Background(), method, arguments{}); err != nil {
			t.Errorf("manual %s: %v", method, err)
		}
	}
	if err := a.syncProfile(context.Background()); err != nil || requests.Load() != 4 {
		t.Fatalf("manual refresh failed: %d %v", requests.Load(), err)
	}
	if err := a.connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, err := a.controller(context.Background(), http.MethodGet, "/version", nil); err != nil {
		t.Fatal(err)
	}
	if err := a.disconnect(context.Background()); err != nil {
		t.Fatal(err)
	}
	restored := &app{
		dataDir: a.dataDir, runDir: a.runDir, profile: a.profile, runProfile: a.runProfile,
		site: a.site, client: a.client, command: a.command, ctx: a.ctx,
		coreBinary: a.coreBinary, controllerAddress: a.controllerAddress,
	}
	restored.core = &coreRuntime{app: restored}
	t.Cleanup(func() { restored.core.close() })
	if err := restored.connect(context.Background()); err != nil {
		t.Fatalf("restored manual subscription cannot connect: %v", err)
	}
	if err := restored.logout(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, err := restored.subscriptionURL(); !errors.Is(err, failure("not_logged_in")) {
		t.Fatalf("manual source survived logout: %v", err)
	}
}

func TestFailedManualImportPreservesRunningSubscription(t *testing.T) {
	a := testSetup(t, false).a
	os.Remove(filepath.Join(a.dataDir, "session.json"))
	writeJSON(filepath.Join(a.dataDir, "settings.json"), map[string]any{"tun.enable": false})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/unauthorized":
			w.WriteHeader(http.StatusUnauthorized)
		case "/invalid":
			io.WriteString(w, manualProfile+"fake-invalid: true\n")
		case "/restart-fails":
			io.WriteString(w, manualProfile+"fake-start-fail: true\n")
		default:
			io.WriteString(w, manualProfile)
		}
	}))
	defer server.Close()
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		if address != a.controllerAddress {
			address = server.Listener.Addr().String()
		}
		return (&net.Dialer{}).DialContext(ctx, network, address)
	}
	a.client.Transport = transport
	defer transport.CloseIdleConnections()
	if err := importForTest(t, a, server.URL+"/good"); err != "" {
		t.Fatal(err)
	}
	if err := a.connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	previous := map[string]string{}
	for _, name := range []string{"session.json", "profile.yaml", "profile.json", "source.yaml"} {
		data, _ := os.ReadFile(filepath.Join(a.dataDir, name))
		previous[name] = string(data)
	}
	for path, expected := range map[string]string{
		"/unauthorized": "invalid_subscription", "/invalid": "invalid_subscription", "/restart-fails": "service_failed",
	} {
		if err := importForTest(t, a, server.URL+path); err != expected {
			t.Fatalf("wrong manual import failure for %s: got %s, want %s", path, err, expected)
		}
		for name, expected := range previous {
			data, _ := os.ReadFile(filepath.Join(a.dataDir, name))
			if string(data) != expected {
				t.Fatalf("failed %s replaced %s", path, name)
			}
		}
		if !a.running(context.Background()) {
			t.Fatalf("failed %s stopped the previous subscription", path)
		}
	}
	for _, target := range []string{"file:///etc/passwd", "ftp://example.com/sub", "https://", "https://example.com/a b"} {
		if _, err := a.call(context.Background(), "import_subscription", arguments{URL: target}); !errors.Is(err, failure("invalid_subscription")) {
			t.Fatalf("accepted invalid link %q: %v", target, err)
		}
	}
}
