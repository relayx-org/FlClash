package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"testing"
	"time"
)

func updateTestApp(t *testing.T, manifest string) *app {
	t.Helper()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/releases/latest.json" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write([]byte(manifest))
	}))
	t.Cleanup(server.Close)
	dir := t.TempDir()
	a := &app{dataDir: dir, runDir: dir, hostConfig: filepath.Join(dir, "agent.json"), client: server.Client(),
		versionFile: filepath.Join(dir, "version"), updateBinary: filepath.Join(dir, "update")}
	if err := a.setConfigValue(context.Background(), "update_url", server.URL+"/releases/"); err != nil {
		t.Fatal(err)
	}
	return a
}

func manifestFor(version string, build int) string {
	return `{"schemaVersion":1,"packageId":"my.iping.client","version":"` + version + `","buildNumber":` +
		strconv.Itoa(build) + `,"notes":"Fixes","downloads":{"linux-agent-` + agentArch() + `":{"url":"https://example.com/a.zip"}}}`
}

func TestUpdateCheckComparesTheManifestWithTheInstalledRelease(t *testing.T) {
	if agentArch() == "" {
		t.Skip("no Linux Agent build for this architecture")
	}
	for _, tc := range []struct {
		installed string
		available bool
	}{{"0.1.9+2026110801", true}, {"0.2.0+2026110901", false}, {"0.2.0+2026110900", true}, {"0.10.0+1", false}} {
		a := updateTestApp(t, manifestFor("0.2.0", 2026110901))
		if err := os.WriteFile(a.versionFile, []byte(tc.installed+"\n"), 0644); err != nil {
			t.Fatal(err)
		}
		result, err := a.checkUpdate(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		data := result.(map[string]any)
		if data["available"] != tc.available || data["version"] != "0.2.0" || data["build"] != int64(2026110901) ||
			data["notes"] != "Fixes" || data["current"] != tc.installed {
			t.Fatalf("installed %s: %#v", tc.installed, data)
		}
	}
}

func TestUpdateCheckRejectsAnUnexpectedManifest(t *testing.T) {
	for _, manifest := range []string{
		`{"schemaVersion":1,"packageId":"other","version":"0.2.0","buildNumber":1}`,
		manifestFor("0.2", 1),
		`{"schemaVersion":1,"packageId":"my.iping.client","version":"0.2.0","buildNumber":1,"downloads":{}}`,
	} {
		if _, err := updateTestApp(t, manifest).checkUpdate(context.Background()); err != failure("invalid_response") {
			t.Fatalf("%s: %v", manifest, err)
		}
	}
}

func TestUpdateInstallRunsTheUpdaterDetachedAndReportsItsResult(t *testing.T) {
	for _, tc := range []struct {
		name   string
		script string
		failed bool
	}{{"success", "exit 0", false}, {"failure", "exit 3", true}} {
		t.Run(tc.name, func(t *testing.T) {
			a := updateTestApp(t, "{}")
			a.hostConfig = ""
			if err := os.WriteFile(a.updateBinary, []byte("#!/bin/sh\n[ \"$1\" = update ] || exit 9\necho updating\n"+tc.script+"\n"), 0755); err != nil {
				t.Fatal(err)
			}
			var child *exec.Cmd
			a.detach = func(name string, args ...string) error {
				child = exec.Command(name, args...)
				return child.Start()
			}
			if _, err := a.installUpdate(context.Background()); err != nil {
				t.Fatal(err)
			}
			if _, err := a.installUpdate(context.Background()); err != failure("busy") {
				t.Fatalf("second install: %v", err)
			}
			if err := child.Wait(); err != nil {
				t.Fatal(err)
			}
			if running, failed := a.updateState(); running || failed != tc.failed {
				t.Fatalf("running %v failed %v", running, failed)
			}
			if log, _ := os.ReadFile(filepath.Join(a.runDir, "update.log")); string(log) != "updating\n" {
				t.Fatalf("log %q", log)
			}
		})
	}
}

func TestUpdateInstallUsesATransientUnitOnSystemd(t *testing.T) {
	a := updateTestApp(t, "{}")
	var called []string
	a.command = func(_ context.Context, name string, args ...string) ([]byte, error) {
		called = append([]string{name}, args...)
		return nil, nil
	}
	if _, err := a.installUpdate(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(called) < 5 || called[0] != "systemd-run" || called[3] != "--unit=iping-agent-update" || called[len(called)-3] != a.updateBinary {
		t.Fatalf("%q", called)
	}
}

func TestAnUnreportedUpdateFailsAfterTheUpdaterLimit(t *testing.T) {
	dir := t.TempDir()
	a := &app{runDir: dir}
	if err := writeJSON(filepath.Join(dir, "update.json"), updateRun{Started: time.Now().Add(-16 * time.Minute).Unix()}); err != nil {
		t.Fatal(err)
	}
	if running, failed := a.updateState(); running || !failed {
		t.Fatalf("running %v failed %v", running, failed)
	}
}
