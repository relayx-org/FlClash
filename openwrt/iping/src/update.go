package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const defaultUpdateURL = "https://video.iping.my/releases/"

var releaseVersion = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)\+([1-9]\d{0,14})$`)

type updateRun struct {
	Started int64 `json:"started"`
}

func agentArch() string {
	return map[string]string{"amd64": "x86_64", "arm64": "aarch64", "arm": "armv7", "mips": "mips", "mipsle": "mipsel"}[runtime.GOARCH]
}

func newerRelease(incoming, current string) bool {
	next, installed := releaseVersion.FindStringSubmatch(incoming), releaseVersion.FindStringSubmatch(current)
	if next == nil {
		return false
	}
	if installed == nil {
		return true
	}
	for i := 1; i <= 4; i++ {
		n, _ := strconv.ParseUint(next[i], 10, 64)
		c, _ := strconv.ParseUint(installed[i], 10, 64)
		if n != c {
			return n > c
		}
	}
	return false
}

func (a *app) installedVersion() string {
	data, _ := os.ReadFile(a.versionFile)
	return strings.TrimSpace(string(data))
}

func (a *app) checkUpdate(ctx context.Context) (any, error) {
	base, err := a.configValue(ctx, "update_url")
	if err != nil || base == "" {
		base = defaultUpdateURL
	}
	if u, err := url.Parse(base); err != nil || u.Scheme != "https" || u.Host == "" || !strings.HasSuffix(u.Path, "/") {
		return nil, failure("invalid_update_url")
	}
	data, err := a.requestURL(ctx, http.MethodGet, base+"latest.json", nil, "", 256*1024, false)
	if err != nil {
		return nil, err
	}
	var manifest struct {
		SchemaVersion int    `json:"schemaVersion"`
		PackageID     string `json:"packageId"`
		Version       string `json:"version"`
		BuildNumber   int64  `json:"buildNumber"`
		Notes         string `json:"notes"`
		Downloads     map[string]struct {
			URL string `json:"url"`
		} `json:"downloads"`
	}
	if json.Unmarshal(data, &manifest) != nil || manifest.SchemaVersion != 1 || manifest.PackageID != "my.iping.client" {
		return nil, failure("invalid_response")
	}
	latest := manifest.Version + "+" + strconv.FormatInt(manifest.BuildNumber, 10)
	if !releaseVersion.MatchString(latest) || manifest.Downloads["linux-agent-"+agentArch()].URL == "" {
		return nil, failure("invalid_response")
	}
	current := a.installedVersion()
	return map[string]any{
		"current": current, "version": manifest.Version, "build": manifest.BuildNumber,
		"notes": manifest.Notes, "available": newerRelease(latest, current),
	}, nil
}

// The updater stops this Agent, so it runs outside the service: a transient unit on
// systemd, whose KillMode would otherwise take it down too, and a new session on procd.
func (a *app) installUpdate(ctx context.Context) (any, error) {
	if running, _ := a.updateState(); running {
		return nil, failure("busy")
	}
	result := filepath.Join(a.runDir, "update.result")
	if err := os.Remove(result); err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, failure("storage_error")
	}
	if err := writeJSON(filepath.Join(a.runDir, "update.json"), updateRun{Started: time.Now().Unix()}); err != nil {
		return nil, failure("storage_error")
	}
	script := []string{"/bin/sh", "-c", `"$1" update > "$2" 2>&1; echo $? > "$3.tmp"; mv "$3.tmp" "$3"`, "sh",
		a.updateBinary, filepath.Join(a.runDir, "update.log"), result}
	var err error
	if a.hostConfig != "" {
		_, err = a.command(ctx, "systemd-run", append([]string{"--quiet", "--collect", "--unit=iping-agent-update"}, script...)...)
	} else {
		err = a.detach(script[0], script[1:]...)
	}
	if err != nil {
		_ = os.Remove(filepath.Join(a.runDir, "update.json"))
		return nil, failure("service_failed")
	}
	return nil, nil
}

func detachProcess(name string, args ...string) error {
	child := exec.Command(name, args...)
	child.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := child.Start(); err != nil {
		return err
	}
	go child.Wait()
	return nil
}

// An update the wrapper never reported on, because the router lost power or the
// process was killed, counts as failed once it outlasts the updater's own limits.
func (a *app) updateState() (running, failed bool) {
	var run updateRun
	if readJSON(filepath.Join(a.runDir, "update.json"), &run) != nil || run.Started == 0 {
		return false, false
	}
	result, err := os.ReadFile(filepath.Join(a.runDir, "update.result"))
	if errors.Is(err, os.ErrNotExist) {
		if time.Since(time.Unix(run.Started, 0)) < 15*time.Minute {
			return true, false
		}
		return false, true
	}
	return false, strings.TrimSpace(string(result)) != "0"
}

func (a *app) updateStatus() (any, error) {
	running, failed := a.updateState()
	return map[string]any{"current": a.installedVersion(), "running": running, "failed": failed}, nil
}
