package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func TestLinuxConfigPersistsAndControlsCoreWithoutUCI(t *testing.T) {
	a := testSetup(t, false).a
	a.hostConfig = filepath.Join(a.dataDir, "agent.json")
	command := a.command
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if name == "/sbin/uci" {
			return nil, fmt.Errorf("UCI must not be called on Linux")
		}
		return command(ctx, name, args...)
	}
	if err := a.setConfigValue(a.ctx, "web_listen", "127.0.0.1:19091"); err != nil {
		t.Fatal(err)
	}
	if err := writeJSON(filepath.Join(a.dataDir, "settings.json"), map[string]any{"tun.enable": false}); err != nil {
		t.Fatal(err)
	}
	if err := a.connect(a.ctx); err != nil {
		t.Fatal(err)
	}
	if !a.enabled(a.ctx) || !a.running(a.ctx) {
		t.Fatal("Linux connection did not persist or start")
	}
	if address, err := a.webAddress(a.ctx); err != nil || address != "127.0.0.1:19091" {
		t.Fatalf("listener = %q, %v", address, err)
	}
	if err := a.disconnect(a.ctx); err != nil {
		t.Fatal(err)
	}
	fresh := &app{hostConfig: a.hostConfig}
	if fresh.enabled(a.ctx) || a.running(a.ctx) {
		t.Fatal("Linux disconnect did not persist or stop")
	}
	if a.firewallPath() != "" {
		t.Fatal("Linux must not manage an OpenWrt firewall include")
	}
	if info, err := os.Stat(a.hostConfig); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("configuration permissions: %v, %v", info, err)
	}
}

func TestLinuxConfigRejectsCorruptionWithoutOverwritingIt(t *testing.T) {
	a := testSetup(t, false).a
	a.hostConfig = filepath.Join(a.dataDir, "agent.json")
	if err := os.WriteFile(a.hostConfig, []byte("broken"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := a.setEnabled(a.ctx, true); err == nil {
		t.Fatal("corrupt configuration was accepted")
	}
	if data, _ := os.ReadFile(a.hostConfig); string(data) != "broken" {
		t.Fatal("corrupt configuration was overwritten")
	}
}

func TestLinuxConfigCancellationDoesNotChangeEnabledIntent(t *testing.T) {
	a := testSetup(t, false).a
	a.hostConfig = filepath.Join(a.dataDir, "agent.json")
	if err := a.setEnabled(a.ctx, false); err != nil {
		t.Fatal(err)
	}
	lock, err := os.OpenFile(filepath.Join(a.dataDir, "config.lock"), os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(a.ctx, 50*time.Millisecond)
	defer cancel()
	if err := a.setEnabled(ctx, true); err != failure("interrupted") {
		t.Fatalf("cancelled write = %v", err)
	}
	if a.enabled(a.ctx) {
		t.Fatal("cancelled request changed the enabled intent")
	}
}
