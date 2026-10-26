package main

import (
	"context"
	"errors"
	"net"
	"os"
	"strings"
	"sync"
	"time"

	"go.yaml.in/yaml/v3"
)

type dashboardCounts struct {
	Groups  int `json:"groups"`
	Proxies int `json:"proxies"`
	Rules   int `json:"rules"`
}

type dashboardProfileCache struct {
	mu       sync.Mutex
	modified time.Time
	size     int64
	counts   dashboardCounts
}

func (a *app) dashboardCounts() (dashboardCounts, error) {
	c := &a.dashboardCache
	c.mu.Lock()
	defer c.mu.Unlock()
	info, err := os.Stat(a.profile)
	if errors.Is(err, os.ErrNotExist) {
		return dashboardCounts{}, nil
	}
	if err != nil {
		return dashboardCounts{}, failure("storage_error")
	}
	if c.modified.Equal(info.ModTime()) && c.size == info.Size() {
		return c.counts, nil
	}
	data, err := os.ReadFile(a.profile)
	if err != nil {
		return dashboardCounts{}, failure("storage_error")
	}
	var profile struct {
		Groups  []any `yaml:"proxy-groups"`
		Proxies []any `yaml:"proxies"`
		Rules   []any `yaml:"rules"`
	}
	if yaml.Unmarshal(data, &profile) != nil {
		return dashboardCounts{}, failure("invalid_subscription")
	}
	c.counts = dashboardCounts{len(profile.Groups), len(profile.Proxies), len(profile.Rules)}
	c.modified, c.size = info.ModTime(), info.Size()
	return c.counts, nil
}

func (a *app) dashboard(ctx context.Context) (any, error) {
	if _, err := a.account(); err != nil {
		return nil, err
	}
	counts, err := a.dashboardCounts()
	if err != nil {
		return nil, err
	}
	settings, err := a.settings(ctx)
	if err != nil {
		return nil, err
	}
	address, _ := a.command(ctx, "/sbin/uci", "-q", "get", "network.lan.ipaddr")
	ip := strings.Split(strings.TrimSpace(string(address)), "/")[0]
	if net.ParseIP(ip) == nil {
		ip = ""
	}
	started := int64(0)
	if child := a.core.current.Load(); child != nil && a.running(ctx) {
		started = child.started.UnixMilli()
	}
	values := settings["values"].(map[string]any)
	network := map[string]any{}
	for _, key := range []string{"allow-lan", "mixed-port", "tun.enable"} {
		network[key] = values[key]
	}
	return map[string]any{"local_ip": ip, "started": started, "counts": counts, "settings": network}, nil
}
