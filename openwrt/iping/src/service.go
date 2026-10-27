package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.yaml.in/yaml/v3"
)

func (a *app) enabled(ctx context.Context) bool {
	value, _ := a.configValue(ctx, "enabled")
	return value == "1"
}

func (a *app) setEnabled(ctx context.Context, enabled bool) error {
	value := "0"
	if enabled {
		value = "1"
	}
	return a.setConfigValue(ctx, "enabled", value)
}

func (a *app) running(ctx context.Context) bool { return a.core != nil && a.core.running() }

func (a *app) replaceProfile(ctx context.Context, files map[string][]byte, restart bool) error {
	previous := map[string][]byte{}
	for path := range files {
		data, err := os.ReadFile(path)
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return failure("storage_error")
		}
		previous[path] = data
	}
	restarting := false
	rollback := func() error {
		for path, data := range previous {
			if data == nil {
				if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
					return failure("rollback_failed")
				}
			} else if writePrivate(path, data) != nil {
				return failure("rollback_failed")
			}
		}
		if restarting && !a.core.closed.Load() {
			restore, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			return a.core.restart(restore)
		}
		return nil
	}
	for path, data := range files {
		if err := writePrivate(path, data); err != nil {
			if rollback() != nil {
				return failure("rollback_failed")
			}
			return failure("storage_error")
		}
	}
	if restart {
		restarting = true
		if err := a.core.restart(ctx); err != nil {
			if rollback() != nil {
				return failure("rollback_failed")
			}
			return err
		}
	}
	return nil
}

func (a *app) syncProfile(ctx context.Context) error {
	target, err := a.subscriptionURL()
	if err != nil {
		return err
	}
	return a.downloadProfile(ctx, target, nil)
}

func validSubscriptionURL(raw string) bool {
	u, err := url.Parse(raw)
	return err == nil && len(raw) <= 8192 && !strings.ContainsAny(raw, " \t\r\n") &&
		(u.Scheme == "http" || u.Scheme == "https") && u.Hostname() != ""
}

func (a *app) queueSubscription(raw string, lock *os.File) (any, error) {
	raw = strings.TrimSpace(raw)
	if !validSubscriptionURL(raw) {
		return nil, failure("invalid_subscription")
	}
	if err := writeJSON(filepath.Join(a.runDir, "subscription-job.json"), raw); err != nil {
		return nil, failure("storage_error")
	}
	return a.startJob("import_subscription", lock)
}

func (a *app) importSubscription(ctx context.Context) error {
	path := filepath.Join(a.runDir, "subscription-job.json")
	defer os.Remove(path)
	var target string
	if readJSON(path, &target) != nil || !validSubscriptionURL(target) {
		return failure("invalid_subscription")
	}
	account, err := a.account()
	if err != nil {
		account = credentials{Site: a.site}
	}
	account.ManualURL = target
	return a.downloadProfile(ctx, target, &account)
}

func (a *app) downloadProfile(ctx context.Context, target string, next *credentials) error {
	manual := next != nil
	if !manual {
		session, err := a.session()
		if err != nil {
			return err
		}
		manual = session.ManualURL != ""
	}
	source, err := a.requestURL(ctx, http.MethodGet, target, nil, "", 8*1024*1024, true)
	if err != nil {
		if manual && errors.Is(err, failure("login_required")) {
			return failure("invalid_subscription")
		}
		return err
	}
	var profile struct {
		Proxies []struct {
			Name string `yaml:"name"`
			Type string `yaml:"type"`
		} `yaml:"proxies"`
	}
	if yaml.Unmarshal(source, &profile) != nil {
		return failure("invalid_subscription")
	}
	if len(profile.Proxies) == 0 {
		return failure("no_nodes")
	}
	for _, proxy := range profile.Proxies {
		if proxy.Name == "" || proxy.Type == "" {
			return failure("invalid_subscription")
		}
	}
	id, err := a.resourceProfileID()
	if next != nil {
		id, err = subscriptionProfileID(*next), nil
	}
	if err != nil {
		return err
	}
	settings, err := a.profileSettingsFor(id)
	if err != nil {
		return err
	}
	candidate, err := a.buildProfile(source, settings)
	if err != nil {
		return err
	}
	if a.validateProfile(ctx, candidate) != nil {
		return failure("invalid_subscription")
	}
	info, _ := json.Marshal(profileInfo{len(profile.Proxies), time.Now().Unix()})
	files := map[string][]byte{
		a.profile:                                candidate,
		filepath.Join(a.dataDir, "source.yaml"):  source,
		filepath.Join(a.dataDir, "profile.json"): info,
	}
	if next != nil {
		files[filepath.Join(a.dataDir, "session.json")], err = json.Marshal(next)
		if err != nil {
			return failure("storage_error")
		}
	}
	if err := ctx.Err(); err != nil {
		return failure("interrupted")
	}
	return a.replaceProfile(ctx, files, a.core.wanted.Load())
}

func (a *app) connect(ctx context.Context) error {
	if _, err := a.subscriptionURL(); err != nil {
		return err
	}
	source, err := os.ReadFile(filepath.Join(a.dataDir, "source.yaml"))
	if err != nil {
		return failure("sync_required")
	}
	settings, err := a.profileSettings()
	if err != nil {
		return err
	}
	candidate, err := a.buildProfile(source, settings)
	if err != nil {
		return err
	}
	if err := a.validateProfile(ctx, candidate); err != nil {
		return err
	}
	current, _ := os.ReadFile(a.profile)
	if !bytes.Equal(current, candidate) {
		if err := a.replaceProfile(ctx, map[string][]byte{a.profile: candidate}, a.core.wanted.Load()); err != nil {
			return err
		}
	}
	previous := a.enabled(ctx)
	if err := a.setEnabled(ctx, true); err != nil {
		return err
	}
	if err := a.core.setRunning(ctx, true); err != nil {
		restore, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if a.setEnabled(restore, previous) != nil {
			return failure("rollback_failed")
		}
		if a.core.setRunning(restore, previous) != nil && !a.core.closed.Load() {
			return failure("rollback_failed")
		}
		return err
	}
	return nil
}

func (a *app) disconnect(ctx context.Context) error {
	if err := a.setEnabled(ctx, false); err != nil {
		return err
	}
	return a.core.setRunning(ctx, false)
}

func (a *app) logout(ctx context.Context) error {
	if err := a.disconnect(ctx); err != nil {
		return err
	}
	for _, path := range []string{
		filepath.Join(a.dataDir, "session.json"), filepath.Join(a.dataDir, "source.yaml"),
		filepath.Join(a.dataDir, "profile.json"), filepath.Join(a.runDir, "login.json"), a.profile,
	} {
		if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
			return failure("storage_error")
		}
	}
	return nil
}
