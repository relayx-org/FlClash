package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"testing"
)

type iptablesFixture struct {
	mu      sync.Mutex
	a       *app
	rules   map[string]map[string]string
	linked  bool
	mutated bool
	auto    bool
	child   *coreChild
}

func newIPTablesFixture(t *testing.T) *iptablesFixture {
	t.Helper()
	a := testSetup(t, false).a
	f := &iptablesFixture{a: a, rules: map[string]map[string]string{}}
	previous := a.command
	a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		f.mu.Lock()
		defer f.mu.Unlock()
		if name == "fw4" {
			return nil, os.ErrNotExist
		}
		if name == "fw3" {
			return nil, nil
		}
		if f.auto {
			child := a.core.current.Load()
			if child != nil {
				select {
				case <-child.done:
					f.rules, f.linked = map[string]map[string]string{}, false
				default:
					if child != f.child {
						f.install("iptables")
						f.child = child
					}
				}
			}
		}
		if name == "ip" {
			switch strings.Join(args, " ") {
			case "-j link show":
				if f.linked {
					return []byte(`[{"ifname":"iping0","ifindex":4}]`), nil
				}
				return []byte(`[]`), nil
			case "link delete dev iping0":
				f.mutated, f.linked = true, false
				return nil, nil
			}
			if strings.Contains(strings.Join(args, " "), "rule show") {
				return []byte(`[]`), nil
			}
			return nil, nil
		}
		if name == "iptables" || name == "ip6tables" {
			if len(args) < 5 || args[0] != "-w" || args[2] != "-t" {
				t.Fatalf("unexpected firewall command %s %v", name, args)
			}
			table, action := args[3], args[4]
			if action == "-S" {
				return []byte(f.rules[name][table]), nil
			}
			f.mutated = true
			var kept []string
			for _, line := range strings.Split(f.rules[name][table], "\n") {
				if action == "-D" && line == "-A "+strings.Join(args[5:], " ") ||
					action == "-F" && strings.HasPrefix(line, "-A "+args[5]+" ") ||
					action == "-X" && line == "-N "+args[5] {
					continue
				}
				kept = append(kept, line)
			}
			f.rules[name][table] = strings.Join(kept, "\n")
			return nil, nil
		}
		return previous(ctx, name, args...)
	}
	return f
}

func (f *iptablesFixture) install(binary string) {
	f.linked = true
	f.rules[binary] = map[string]string{}
	for _, chain := range iptablesChains {
		f.rules[binary][chain.table] += fmt.Sprintf("-N %s\n-A %s -i iping0 -j ACCEPT\n-A %s -j %s\n", chain.name, chain.name, chain.hook, chain.name)
	}
}

func TestIPTablesLeaseLifecycle(t *testing.T) {
	for _, ipv6 := range []bool{false, true} {
		t.Run(fmt.Sprint(ipv6), func(t *testing.T) {
			f := newIPTablesFixture(t)
			a := f.a
			if err := a.acquireNetwork(a.ctx, "iping0", ipv6); err != nil {
				t.Fatal(err)
			}
			f.install("iptables")
			if ipv6 {
				if err := a.networkReady(a.ctx); !errors.Is(err, failure("service_failed")) {
					t.Fatalf("missing IPv6 rules accepted: %v", err)
				}
				f.install("ip6tables")
			}
			if err := a.networkReady(a.ctx); err != nil {
				t.Fatal(err)
			}
			if err := a.cleanNetwork(a.ctx); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(a.leasePath()); !os.IsNotExist(err) {
				t.Fatalf("lease was retained: %v", err)
			}
		})
	}
}

func TestIPTablesForeignRulesAreNeverClaimedOrRemoved(t *testing.T) {
	for _, scenario := range []string{"preexisting", "replaced", "foreign-reference", "partial-cleanup"} {
		t.Run(scenario, func(t *testing.T) {
			f := newIPTablesFixture(t)
			a := f.a
			if scenario == "preexisting" {
				f.install("iptables")
				if err := a.acquireNetwork(a.ctx, "iping0", false); !errors.Is(err, failure("service_conflict")) {
					t.Fatalf("foreign rules claimed: %v", err)
				}
			} else {
				if err := a.acquireNetwork(a.ctx, "iping0", false); err != nil {
					t.Fatal(err)
				}
				f.install("iptables")
				if err := a.networkReady(a.ctx); err != nil {
					t.Fatal(err)
				}
				switch scenario {
				case "replaced":
					f.rules["iptables"]["nat"] = strings.ReplaceAll(f.rules["iptables"]["nat"], "ACCEPT", "DROP")
				case "foreign-reference":
					f.rules["iptables"]["nat"] += "-A foreign -j mihomo-output\n"
				case "partial-cleanup":
					f.rules["iptables"]["filter"] = ""
				}
				err := a.cleanNetwork(a.ctx)
				if scenario == "partial-cleanup" {
					if err != nil || !f.mutated {
						t.Fatalf("partial cleanup failed: %v", err)
					}
					return
				}
				if !errors.Is(err, failure("service_conflict")) {
					t.Fatalf("foreign rules accepted: %v", err)
				}
			}
			if f.mutated {
				t.Fatal("foreign firewall was mutated")
			}
		})
	}
}

func TestFirewallDetectionAndCoreEnvironment(t *testing.T) {
	t.Setenv("DISABLE_NFTABLES", "inherited")
	for _, backend := range []string{nftablesBackend, iptablesBackend} {
		a := testSetup(t, false).a
		a.command = func(ctx context.Context, name string, args ...string) ([]byte, error) {
			if name == "fw4" && backend == nftablesBackend || name == "fw3" && backend == iptablesBackend {
				return nil, nil
			}
			return nil, os.ErrNotExist
		}
		got, err := a.detectFirewall(a.ctx)
		if err != nil || got != backend {
			t.Fatalf("backend = %q, %v", got, err)
		}
		var values []string
		for _, value := range coreEnvironment(got) {
			if strings.HasPrefix(value, "DISABLE_NFTABLES=") {
				values = append(values, value)
			}
		}
		if len(values) != 1 || values[0] != fmt.Sprintf("DISABLE_NFTABLES=%t", backend == iptablesBackend) {
			t.Fatalf("backend environment = %v", values)
		}
	}
}

func TestIPTablesFirewallReloadRestartsOnlyTheWantedCore(t *testing.T) {
	f := newIPTablesFixture(t)
	a := f.a
	f.auto = true
	data, err := a.buildProfile([]byte("proxies: [{name: direct, type: direct}]\n"), nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := writePrivate(a.profile, data); err != nil {
		t.Fatal(err)
	}
	if err := a.core.setRunning(a.ctx, true); err != nil {
		t.Fatal(err)
	}
	previous := a.core.current.Load()
	if value := previous.cmd.Env[len(previous.cmd.Env)-1]; value != "DISABLE_NFTABLES=true" {
		t.Fatalf("Core did not use iptables: %s", value)
	}
	f.mu.Lock()
	f.rules["iptables"]["filter"] = ""
	f.mu.Unlock()
	waitUntil(t, func() bool { return a.core.current.Load() != previous && a.core.running() })
	if err := a.core.setRunning(a.ctx, false); err != nil {
		t.Fatal(err)
	}
	if a.core.current.Load() != nil || a.core.wanted.Load() {
		t.Fatal("network recovery retained the stopped Core")
	}
}

func TestIPTablesRejectsNFTablesOnlyAddressSetsBeforeStartingCore(t *testing.T) {
	for _, key := range []string{"route-address-set", "route-exclude-address-set"} {
		t.Run(key, func(t *testing.T) {
			a := newIPTablesFixture(t).a
			data, err := a.buildProfile([]byte("tun:\n  "+key+": [private]\n"), nil)
			if err != nil {
				t.Fatal(err)
			}
			if err := writePrivate(a.profile, data); err != nil {
				t.Fatal(err)
			}
			if err := a.core.setRunning(a.ctx, true); !errors.Is(err, failure("invalid_request")) {
				t.Fatalf("unsupported profile result: %v", err)
			}
			if a.core.current.Load() != nil {
				t.Fatal("Core started with unsupported address sets")
			}
		})
	}
}
