package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"go.yaml.in/yaml/v3"
)

type controllerStatusError int

func (e controllerStatusError) Error() string { return "controller_unavailable" }
func (e controllerStatusError) Unwrap() error { return failure("controller_unavailable") }

func (a *app) controller(ctx context.Context, method, path string, body []byte) ([]byte, error) {
	if _, err := a.account(); err != nil {
		return nil, err
	}
	if !a.running(ctx) {
		return nil, failure("controller_unavailable")
	}
	return a.controllerRequest(ctx, method, path, body)
}

func (a *app) controllerRequest(ctx context.Context, method, path string, body []byte) ([]byte, error) {
	data, err := os.ReadFile(a.runProfile)
	var config struct {
		Address string `yaml:"external-controller"`
		Secret  string `yaml:"secret"`
	}
	if err != nil || yaml.Unmarshal(data, &config) != nil {
		return nil, failure("controller_unavailable")
	}
	host, port, err := net.SplitHostPort(config.Address)
	if err != nil {
		return nil, failure("controller_unavailable")
	}
	number, err := strconv.Atoi(port)
	if err != nil || number < 1 || number > 65535 {
		return nil, failure("controller_unavailable")
	}
	ip := net.ParseIP(host)
	if host == "" || (ip != nil && ip.IsUnspecified()) {
		host = "127.0.0.1"
	} else if host != "localhost" && (ip == nil || !localIP(ip)) {
		return nil, failure("controller_unavailable")
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://"+net.JoinHostPort(host, port)+path, bytes.NewReader(body))
	if err != nil {
		return nil, failure("invalid_request")
	}
	if config.Secret != "" {
		req.Header.Set("Authorization", "Bearer "+config.Secret)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := a.client.Do(req)
	if err != nil {
		return nil, failure("controller_unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, controllerStatusError(resp.StatusCode)
	}
	const limit = 16 * 1024 * 1024
	data, err = io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil || len(data) > limit {
		return nil, failure("invalid_response")
	}
	return data, nil
}

func localIP(ip net.IP) bool {
	if ip.IsLoopback() {
		return true
	}
	addresses, err := net.InterfaceAddrs()
	if err != nil {
		return false
	}
	for _, address := range addresses {
		if network, ok := address.(*net.IPNet); ok && network.IP.Equal(ip) {
			return true
		}
	}
	return false
}

func (a *app) controllerReady(ctx context.Context) error {
	if _, err := a.controllerRequest(ctx, http.MethodGet, "/version", nil); err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://"+a.controllerAddress+"/version", nil)
	if err != nil {
		return err
	}
	response, err := a.client.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		return failure("service_conflict")
	}
	return nil
}

type proxyData struct {
	Name          string   `json:"name"`
	Icon          string   `json:"icon,omitempty"`
	Type          string   `json:"type"`
	Now           string   `json:"now,omitempty"`
	Fixed         string   `json:"fixed,omitempty"`
	Count         int      `json:"count,omitempty"`
	SelectedIndex int      `json:"selected_index"`
	All           []string `json:"all,omitempty"`
	Hidden        bool     `json:"hidden,omitempty"`
	History       []struct {
		Delay int `json:"delay"`
	} `json:"history,omitempty"`
}

func (a *app) proxyMap(ctx context.Context) (map[string]proxyData, error) {
	data, err := a.controller(ctx, http.MethodGet, "/proxies", nil)
	if err != nil {
		return nil, err
	}
	var result struct {
		Proxies map[string]proxyData `json:"proxies"`
	}
	if json.Unmarshal(data, &result) != nil || result.Proxies == nil {
		return nil, failure("invalid_response")
	}
	return result.Proxies, nil
}

func pageBounds(offset, total int) (int, int) {
	if offset < 0 || offset > total {
		offset = 0
	}
	end := offset + 60
	if end > total {
		end = total
	}
	return offset, end
}

func (a *app) proxies(ctx context.Context, args arguments) (any, error) {
	proxies, err := a.proxyMap(ctx)
	if err != nil {
		return nil, err
	}
	mode, err := a.coreMode(ctx)
	if err != nil {
		return nil, err
	}
	custom, err := a.profileSettings()
	if err != nil {
		return nil, err
	}
	icons, _ := custom["custom.icons"].(map[string]any)
	globalConfigured := false
	if mode == "rule" {
		data, readErr := os.ReadFile(a.runProfile)
		var config struct {
			Groups []struct {
				Name string `yaml:"name"`
			} `yaml:"proxy-groups"`
		}
		if readErr != nil || yaml.Unmarshal(data, &config) != nil {
			return nil, failure("controller_unavailable")
		}
		for _, group := range config.Groups {
			globalConfigured = globalConfigured || group.Name == "GLOBAL"
		}
	}
	groups := []proxyData{}
	visible := map[string]bool{}
	for name, proxy := range proxies {
		if len(proxy.All) == 0 || !proxyGroupVisible(mode, name, proxy.Hidden, globalConfigured) {
			continue
		}
		visible[name] = true
		proxy.Name = name
		if icon, ok := icons[name].(string); ok {
			proxy.Icon = icon
		}
		names := filteredProxyNames(proxy.All, proxies, args)
		proxy.Count, proxy.SelectedIndex = len(names), -1
		for index, node := range names {
			if node == proxy.Now {
				proxy.SelectedIndex = index
				break
			}
		}
		proxy.All, proxy.History = nil, nil
		groups = append(groups, proxy)
	}
	sort.Slice(groups, func(i, j int) bool {
		if groups[i].Name == "GLOBAL" || groups[j].Name == "GLOBAL" {
			return groups[j].Name == "GLOBAL"
		}
		return groups[i].Name < groups[j].Name
	})
	group := args.Group
	if group == "" && len(groups) > 0 {
		group = groups[0].Name
	}
	items := []proxyData{}
	names := []string{}
	if visible[group] {
		names = filteredProxyNames(proxies[group].All, proxies, args)
	}
	for _, name := range names {
		proxy := proxies[name]
		proxy.Name, proxy.All = name, nil
		if len(proxy.History) > 0 {
			proxy.History = proxy.History[len(proxy.History)-1:]
			if proxy.History[0].Delay <= 0 {
				proxy.History[0].Delay = -1
			}
		}
		items = append(items, proxy)
	}
	selected := -1
	for index, item := range items {
		if item.Name == proxies[group].Now {
			selected = index
			break
		}
	}
	start, end := pageBounds(args.Offset, len(items))
	return map[string]any{"groups": groups, "group": group, "total": len(items), "offset": start, "selected_index": selected, "items": items[start:end]}, nil
}

func filteredProxyNames(names []string, proxies map[string]proxyData, args arguments) []string {
	filtered := []string{}
	for _, name := range names {
		if matchesTerms(name+"\n"+proxies[name].Type, args.Query) {
			filtered = append(filtered, name)
		}
	}
	if args.HideTimeout {
		available := []string{}
		for _, name := range filtered {
			if !proxyTimedOut(proxies[name]) {
				available = append(available, name)
			}
		}
		if len(available) > 0 {
			filtered = available
		}
	}
	if args.Sort == "name" {
		sort.Strings(filtered)
	} else if args.Sort == "delay" {
		sort.SliceStable(filtered, func(i, j int) bool {
			return proxyDelayRank(proxies[filtered[i]]) < proxyDelayRank(proxies[filtered[j]])
		})
	}
	return filtered
}

func proxyDelay(proxy proxyData) int {
	if len(proxy.History) == 0 {
		return 0
	}
	return proxy.History[len(proxy.History)-1].Delay
}

func proxyTimedOut(proxy proxyData) bool {
	return len(proxy.History) > 0 && proxyDelay(proxy) <= 0
}

func matchesTerms(text, query string) bool {
	text = strings.ToLower(text)
	for _, term := range strings.Fields(strings.ToLower(query)) {
		if !strings.Contains(text, term) {
			return false
		}
	}
	return true
}

func proxyDelayRank(proxy proxyData) int {
	delay := proxyDelay(proxy)
	if delay <= 0 {
		return int(^uint(0) >> 1)
	}
	return delay
}

func (a *app) selectProxy(ctx context.Context, args arguments) error {
	proxies, err := a.proxyMap(ctx)
	if err != nil {
		return err
	}
	group, exists := proxies[args.Group]
	if !exists || (group.Type != "Selector" && group.Type != "URLTest" && group.Type != "Fallback") {
		return failure("invalid_request")
	}
	path := "/proxies/" + url.PathEscape(args.Group)
	if args.Name == "" && group.Type != "Selector" {
		_, err := a.controller(ctx, http.MethodDelete, path, nil)
		if err == nil && args.CloseConnections {
			_, err = a.controller(ctx, http.MethodDelete, "/connections", nil)
		}
		return err
	}
	for _, name := range group.All {
		if name == args.Name {
			body, _ := json.Marshal(map[string]string{"name": name})
			_, err := a.controller(ctx, http.MethodPut, path, body)
			if err == nil && args.CloseConnections {
				_, err = a.controller(ctx, http.MethodDelete, "/connections", nil)
			}
			return err
		}
	}
	return failure("invalid_request")
}

func (a *app) delayProxy(ctx context.Context, name string, testURL ...string) (any, error) {
	if name == "" || len(name) > 4096 {
		return nil, failure("invalid_request")
	}
	target := "https://www.gstatic.com/generate_204"
	if len(testURL) > 0 && testURL[0] != "" {
		parsed, err := url.Parse(testURL[0])
		if err != nil || len(testURL[0]) > 2048 || (parsed.Scheme != "http" && parsed.Scheme != "https") || parsed.Host == "" || parsed.User != nil || parsed.Fragment != "" {
			return nil, failure("invalid_request")
		}
		target = parsed.String()
	}
	query := url.Values{"url": {target}, "timeout": {"5000"}}
	data, err := a.controller(ctx, http.MethodGet, "/proxies/"+url.PathEscape(name)+"/delay?"+query.Encode(), nil)
	if err != nil {
		var status controllerStatusError
		if errors.As(err, &status) {
			switch int(status) {
			case http.StatusGatewayTimeout:
				return map[string]int{"delay": -1}, nil
			case http.StatusServiceUnavailable:
				return map[string]int{"delay": -2}, nil
			}
		}
		return nil, err
	}
	var result struct {
		Delay int `json:"delay"`
	}
	if json.Unmarshal(data, &result) != nil {
		return nil, failure("invalid_response")
	}
	return result, nil
}

func (a *app) setMode(ctx context.Context, mode string) error {
	if mode != "rule" && mode != "global" && mode != "direct" {
		return failure("invalid_request")
	}
	settings, err := a.profileSettings()
	if err != nil {
		return err
	}
	path := filepath.Join(a.dataDir, "settings.json")
	previous, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return failure("storage_error")
	}
	settings["mode"] = mode
	encoded, err := a.encodeProfileSettings(settings)
	if err != nil {
		return err
	}
	if err := writePrivate(path, encoded); err != nil {
		return failure("storage_error")
	}
	if a.running(ctx) {
		body, _ := json.Marshal(map[string]string{"mode": mode})
		if _, err := a.controller(ctx, http.MethodPatch, "/configs", body); err != nil {
			var restore error
			if previous == nil {
				restore = os.Remove(path)
			} else {
				restore = writePrivate(path, previous)
			}
			if restore != nil {
				return failure("rollback_failed")
			}
			return err
		}
	}
	return nil
}

type connectionData struct {
	ID       string `json:"id"`
	Metadata struct {
		Network         string `json:"network"`
		Type            string `json:"type"`
		Host            string `json:"host"`
		DestinationIP   string `json:"destinationIP"`
		DestinationPort string `json:"destinationPort"`
		SourceIP        string `json:"sourceIP"`
		SourcePort      string `json:"sourcePort"`
	} `json:"metadata"`
	Upload      int64    `json:"upload"`
	Download    int64    `json:"download"`
	Start       string   `json:"start"`
	Chains      []string `json:"chains"`
	Rule        string   `json:"rule"`
	RulePayload string   `json:"rulePayload"`
}

type connectionSnapshot struct {
	DownloadTotal int64            `json:"downloadTotal"`
	UploadTotal   int64            `json:"uploadTotal"`
	Memory        int64            `json:"memory"`
	Connections   []connectionData `json:"connections"`
}

func (a *app) snapshot(ctx context.Context) (connectionSnapshot, error) {
	var result connectionSnapshot
	data, err := a.controller(ctx, http.MethodGet, "/connections", nil)
	if err != nil {
		return result, err
	}
	if json.Unmarshal(data, &result) != nil {
		return result, failure("invalid_response")
	}
	return result, nil
}

func (a *app) telemetry(ctx context.Context) (any, error) {
	if !a.running(ctx) {
		settings, err := a.settings(ctx)
		if err != nil {
			return nil, err
		}
		return map[string]any{"running": false, "upload": 0, "download": 0, "memory": 0, "connections": 0, "mode": settings["values"].(map[string]any)["mode"]}, nil
	}
	snapshot, err := a.snapshot(ctx)
	if err != nil {
		return nil, err
	}
	mode, err := a.coreMode(ctx)
	if err != nil {
		return nil, err
	}
	return map[string]any{"running": true, "upload": snapshot.UploadTotal, "download": snapshot.DownloadTotal, "memory": snapshot.Memory, "connections": len(snapshot.Connections), "mode": mode}, nil
}

func (a *app) connections(ctx context.Context, args arguments) (any, error) {
	snapshot, err := a.snapshot(ctx)
	if err != nil {
		return nil, err
	}
	items := []connectionData{}
	query := strings.ToLower(args.Query)
	for _, connection := range snapshot.Connections {
		metadata := connection.Metadata
		if matchesTerms(metadata.Host+" "+metadata.DestinationIP+" "+metadata.SourceIP+" "+metadata.Network+" "+metadata.Type+" "+connection.Rule+" "+connection.RulePayload+" "+strings.Join(connection.Chains, " "), query) {
			items = append(items, connection)
		}
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Start > items[j].Start })
	start, end := pageBounds(args.Offset, len(items))
	return map[string]any{"items": items[start:end], "total": len(items), "offset": start}, nil
}

func (a *app) logs() (any, error) {
	if _, err := a.account(); err != nil {
		return nil, err
	}
	file, err := os.Open(filepath.Join(a.runDir, "core.log"))
	if os.IsNotExist(err) {
		return map[string]any{"lines": []string{}}, nil
	}
	if err != nil {
		return nil, failure("storage_error")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return nil, failure("storage_error")
	}
	if info.Size() > 64*1024 {
		file.Seek(-64*1024, io.SeekEnd)
	}
	data, err := io.ReadAll(io.LimitReader(file, 64*1024))
	if err != nil {
		return nil, failure("storage_error")
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if info.Size() > 64*1024 && len(lines) > 0 {
		lines = lines[1:]
	}
	if len(lines) > 200 {
		lines = lines[len(lines)-200:]
	}
	return map[string]any{"lines": lines}, nil
}

func (a *app) coreMode(ctx context.Context) (string, error) {
	var config struct {
		Mode string `json:"mode"`
	}
	data, err := a.controller(ctx, http.MethodGet, "/configs", nil)
	if err != nil || json.Unmarshal(data, &config) != nil || (config.Mode != "rule" && config.Mode != "global" && config.Mode != "direct") {
		return "", failure("controller_unavailable")
	}
	return config.Mode, nil
}

func proxyGroupVisible(mode, name string, hidden, globalConfigured bool) bool {
	return mode != "direct" && (mode != "rule" || !hidden && (name != "GLOBAL" || globalConfigured))
}
