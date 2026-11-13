package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDisconnectedManualSubscriptionProxies(t *testing.T) {
	a := testSetup(t, false).a
	if err := writeJSON(filepath.Join(a.dataDir, "session.json"), credentials{ManualURL: "https://example.com/sub?token=private", Site: a.site}); err != nil {
		t.Fatal(err)
	}
	var source strings.Builder
	source.WriteString("proxies:\n")
	for i := 0; i < 75; i++ {
		fmt.Fprintf(&source, "- {name: 'Node %02d', type: ss, password: private}\n", i)
	}
	source.WriteString("proxy-groups:\n- {name: PROXY, type: select, include-all-proxies: true}\n- {name: Hidden, type: select, proxies: [DIRECT], hidden: true}\n")
	if err := writePrivate(a.profile, []byte(source.String())); err != nil {
		t.Fatal(err)
	}
	if err := writePrivate(a.runProfile, []byte("proxy-groups: [{name: Stale, type: select, proxies: [DIRECT]}]\n")); err != nil {
		t.Fatal(err)
	}
	result, err := a.call(context.Background(), "proxies", arguments{Offset: 60, HideTimeout: true})
	if err != nil {
		t.Fatal(err)
	}
	page := result.(map[string]any)
	groups := page["groups"].([]proxyData)
	items := page["items"].([]proxyData)
	if len(groups) != 1 || groups[0].Name != "PROXY" || groups[0].Type != "Selector" || groups[0].Count != 75 || groups[0].Now != "" || groups[0].SelectedIndex != -1 {
		t.Fatal(groups)
	}
	if page["offset"] != 60 || page["total"] != 75 || len(items) != 15 || items[0].Name != "Node 60" || items[0].Type != "Shadowsocks" || len(items[0].History) != 0 {
		t.Fatal(page)
	}
	encoded, err := json.Marshal(result)
	if err != nil || strings.Contains(string(encoded), "private") {
		t.Fatal("proxy preview exposed credentials", err)
	}
	if a.running(context.Background()) || a.enabled(context.Background()) {
		t.Fatal("browsing proxies started Core")
	}
	result, err = a.proxies(context.Background(), arguments{Query: "node 07 shadowsocks", Sort: "name"})
	if err != nil || result.(map[string]any)["total"] != 1 {
		t.Fatal(result, err)
	}
	for _, mode := range []string{"global", "direct"} {
		if err := a.setMode(context.Background(), mode); err != nil {
			t.Fatal(err)
		}
		result, err = a.proxies(context.Background(), arguments{})
		if err != nil {
			t.Fatal(err)
		}
		groups = result.(map[string]any)["groups"].([]proxyData)
		if mode == "global" && (len(groups) != 3 || groups[len(groups)-1].Name != "GLOBAL") || mode == "direct" && len(groups) != 0 {
			t.Fatal(mode, groups)
		}
	}
}

func TestProxyPreviewUsesConfiguredMembersAndFilters(t *testing.T) {
	a := testSetup(t, false).a
	source := "proxies: [{name: HK, type: mieru}, {name: JP, type: vless}]\nproxy-groups:\n- {name: PROXY, type: select, proxies: [JP, HK]}\n- {name: Asia, type: url-test, include-all-proxies: true, filter: '(?<=H)K'}\n- {name: GLOBAL, type: fallback, proxies: [PROXY]}\n"
	if err := writePrivate(a.profile, []byte(source)); err != nil {
		t.Fatal(err)
	}
	result, err := a.proxies(context.Background(), arguments{Group: "PROXY"})
	if err != nil {
		t.Fatal(err)
	}
	page := result.(map[string]any)
	groups := page["groups"].([]proxyData)
	items := page["items"].([]proxyData)
	if len(groups) != 3 || groups[0].Count != 1 || groups[0].Type != "URLTest" || groups[2].Name != "GLOBAL" || groups[2].Type != "Fallback" {
		t.Fatal(groups)
	}
	if len(items) != 2 || items[0].Name != "JP" || items[0].Type != "Vless" || items[1].Name != "HK" || items[1].Type != "Mieru" {
		t.Fatal(items)
	}
}

func TestProxyPreviewRejectsMissingSessionOrBrokenProfile(t *testing.T) {
	a := testSetup(t, false).a
	if err := writePrivate(a.profile, []byte("proxy-groups: [")); err != nil {
		t.Fatal(err)
	}
	if _, err := a.proxies(context.Background(), arguments{}); err != failure("storage_error") {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(a.dataDir, "session.json")); err != nil {
		t.Fatal(err)
	}
	if _, err := a.proxies(context.Background(), arguments{}); err != failure("not_logged_in") {
		t.Fatal(err)
	}
}

func TestRunningProxyQueriesKeepControllerSelections(t *testing.T) {
	a, selected, _ := probeFixture(t)
	for _, name := range []string{"node-a", "node-b"} {
		selected.Store(name)
		result, err := a.proxies(context.Background(), arguments{})
		if err != nil {
			t.Fatal(err)
		}
		groups := result.(map[string]any)["groups"].([]proxyData)
		if len(groups) != 1 || groups[0].Now != name {
			t.Fatal(groups)
		}
	}
}
