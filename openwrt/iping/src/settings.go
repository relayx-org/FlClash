package main

import (
	"bytes"
	"context"
	"math"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"go.yaml.in/yaml/v3"
)

type settingSpec struct {
	Kind    string
	Default any
	Choices []string
	Min     int
	Max     int
}

var settingsSpec = map[string]settingSpec{
	"hosts":                               {Kind: "hosts", Default: map[string]string{}, Max: 2048},
	"authentication":                      {Kind: "authentication", Default: []string{}, Max: 2048},
	"dns.nameserver-policy":               {Kind: "nameserver_policy", Default: map[string]string{}, Max: 2048},
	"dns.proxy-server-nameserver-policy":  {Kind: "proxy_server_nameserver_policy", Default: map[string]string{}, Max: 2048},
	"log-level":                           {"enum", "info", []string{"silent", "error", "warning", "info", "debug"}, 0, 0},
	"allow-lan":                           {"bool", true, nil, 0, 0},
	"ipv6":                                {"bool", false, nil, 0, 0},
	"unified-delay":                       {"bool", true, nil, 0, 0},
	"tcp-concurrent":                      {"bool", true, nil, 0, 0},
	"find-process-mode":                   {"enum", "off", []string{"off", "strict", "always"}, 0, 0},
	"mixed-port":                          {"int", 7890, nil, 1024, 49151},
	"port":                                {"int", 0, nil, 0, 49151},
	"socks-port":                          {"int", 0, nil, 0, 49151},
	"redir-port":                          {"int", 0, nil, 0, 49151},
	"tproxy-port":                         {"int", 0, nil, 0, 49151},
	"geodata-loader":                      {"enum", "standard", []string{"standard", "memconservative"}, 0, 0},
	"disable-keep-alive":                  {"bool", false, nil, 0, 0},
	"keep-alive-idle":                     {"int", 30, nil, 1, 3600},
	"keep-alive-interval":                 {"int", 30, nil, 1, 3600},
	"tun.enable":                          {"bool", true, nil, 0, 0},
	"tun.device":                          {"string", "iping0", nil, 0, 64},
	"tun.stack":                           {"enum", "mixed", []string{"system", "gvisor", "mixed"}, 0, 0},
	"tun.mtu":                             {"int", 9000, nil, 1280, 65535},
	"tun.gso":                             {"bool", false, nil, 0, 0},
	"tun.gso-max-size":                    {"int", 65536, nil, 1, 1048576},
	"tun.dns-hijack":                      {"list", []string{"any:53"}, nil, 0, 2048},
	"dns.enable":                          {"bool", true, nil, 0, 0},
	"dns.listen":                          {"listen", "127.0.0.1:1053", nil, 0, 255},
	"dns.ipv6":                            {"bool", false, nil, 0, 0},
	"dns.enhanced-mode":                   {"enum", "fake-ip", []string{"normal", "redir-host", "fake-ip"}, 0, 0},
	"dns.cache-algorithm":                 {"enum", "lru", []string{"lru", "arc"}, 0, 0},
	"dns.fake-ip-range":                   {"cidr", "198.18.0.1/16", nil, 0, 64},
	"dns.fake-ip-range6":                  {"cidr", "fc00::/18", nil, 0, 64},
	"dns.fake-ip-ttl":                     {"int", 1, nil, 1, 86400},
	"dns.fake-ip-filter":                  {"list", []string{}, nil, 0, 2048},
	"dns.fake-ip-filter-mode":             {"enum", "blacklist", []string{"blacklist", "whitelist", "rule"}, 0, 0},
	"dns.respect-rules":                   {"bool", false, nil, 0, 0},
	"dns.prefer-h3":                       {"bool", false, nil, 0, 0},
	"dns.use-hosts":                       {"bool", true, nil, 0, 0},
	"dns.use-system-hosts":                {"bool", true, nil, 0, 0},
	"dns.direct-nameserver-follow-policy": {"bool", false, nil, 0, 0},
	"dns.nameserver":                      {"nameserver", []string{"1.1.1.1", "223.5.5.5"}, nil, 0, 2048},
	"dns.default-nameserver":              {"nameserver", []string{"1.1.1.1", "223.5.5.5"}, nil, 0, 2048},
	"dns.proxy-server-nameserver":         {"nameserver", []string{}, nil, 0, 2048},
	"dns.direct-nameserver":               {"nameserver", []string{}, nil, 0, 2048},
	"dns.fallback":                        {"nameserver", []string{}, nil, 0, 2048},
}

func stringList(value any) []string {
	switch value := value.(type) {
	case []string:
		return value
	case []any:
		result := []string{}
		for _, item := range value {
			if text, ok := item.(string); ok {
				result = append(result, text)
			}
		}
		return result
	case string:
		if value != "" {
			return []string{value}
		}
	}
	return []string{}
}

func yamlSetting(config map[string]any, path string) any {
	var value any = config
	for _, key := range strings.Split(path, ".") {
		object, ok := value.(map[string]any)
		if !ok {
			return nil
		}
		value = object[key]
	}
	return value
}

func (a *app) settings(ctx context.Context) (map[string]any, error) {
	account, err := a.account()
	if err != nil {
		return nil, err
	}
	local, err := a.profileSettings()
	if err != nil {
		return nil, err
	}
	var source map[string]any
	data, err := os.ReadFile(filepath.Join(a.dataDir, "source.yaml"))
	if err != nil && !os.IsNotExist(err) {
		return nil, failure("storage_error")
	}
	if err == nil && (len(data) > 8*1024*1024 || yaml.Unmarshal(data, &source) != nil) {
		return nil, failure("storage_error")
	}
	values := map[string]any{}
	overrides := map[string]bool{}
	for key, spec := range settingsSpec {
		value := spec.Default
		if !ownedSetting(key) && !strings.HasPrefix(key, "custom.") {
			if actual := yamlSetting(source, key); actual != nil {
				value = actual
			}
		}
		saved, exists := local[key]
		if exists {
			value = saved
		}
		values[key] = value
		if isScopedSetting(key) && !ownedSetting(key) {
			overrides[key] = exists
		}
	}
	id, err := a.resourceProfileID()
	if err != nil {
		return nil, err
	}
	return map[string]any{"values": values, "overrides": overrides, "profile_id": id, "profile_label": account.Email}, nil
}

func validateSettings(changes map[string]any) error {
	if len(changes) == 0 || len(changes) > len(settingsSpec) {
		return failure("invalid_request")
	}
	for key, value := range changes {
		spec, exists := settingsSpec[key]
		if !exists {
			return failure("invalid_request")
		}
		if value == nil && isScopedSetting(key) && !ownedSetting(key) {
			continue
		}
		switch spec.Kind {
		case "rules":
			if _, err := resourceRules(value); err != nil {
				return err
			}
		case "scripts":
			if _, err := resourceScripts(value); err != nil {
				return err
			}
		case "bindings":
			if _, err := parseResourceBindings(value); err != nil {
				return err
			}
		case "proxies":
			if _, err := resourceProxies(value); err != nil {
				return err
			}
		case "providers":
			if _, err := resourceProviders(value); err != nil {
				return err
			}
		case "filters":
			if _, err := resourceFilters(value); err != nil {
				return err
			}
		case "bool":
			if _, ok := value.(bool); !ok {
				return failure("invalid_request")
			}
		case "int":
			number, ok := value.(float64)
			if !ok || math.Trunc(number) != number || number < float64(spec.Min) || number > float64(spec.Max) {
				return failure("invalid_request")
			}
			if strings.HasSuffix(key, "port") && number != 0 && number < 1024 {
				return failure("invalid_request")
			}
		case "list", "nameserver", "authentication":
			items, ok := value.([]any)
			if !ok || len(items) > 128 {
				return failure("invalid_request")
			}
			for _, item := range items {
				text, ok := item.(string)
				if !ok || text == "" || len(text) > spec.Max || strings.ContainsAny(text, "\x00\r\n") {
					return failure("invalid_request")
				}
				if spec.Kind == "authentication" {
					parts := strings.SplitN(text, ":", 2)
					if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
						return failure("invalid_request")
					}
				}
			}
		case "map", "hosts", "nameserver_policy", "proxy_server_nameserver_policy":
			entries, ok := value.(map[string]any)
			if !ok || len(entries) > 128 {
				return failure("invalid_request")
			}
			for name, raw := range entries {
				text, ok := raw.(string)
				if !ok || name == "" || len(name) > 255 || len(text) > spec.Max || strings.ContainsAny(name+text, "\x00\r\n") {
					return failure("invalid_request")
				}
				if key == "custom.icons" {
					u, err := url.Parse(text)
					if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" || u.User != nil {
						return failure("invalid_request")
					}
				}
			}
		case "script":
			text, ok := value.(string)
			if !ok || len(text) > spec.Max || strings.ContainsRune(text, 0) {
				return failure("invalid_request")
			}
		default:
			text, ok := value.(string)
			if !ok || strings.ContainsAny(text, "\x00\r\n") {
				return failure("invalid_request")
			}
			if spec.Kind == "enum" {
				found := false
				for _, option := range spec.Choices {
					found = found || option == text
				}
				if !found {
					return failure("invalid_request")
				}
			} else if text == "" || len(text) > spec.Max {
				return failure("invalid_request")
			}
			if spec.Kind == "listen" {
				if text == "" {
					continue
				}
				host, port, err := net.SplitHostPort(text)
				number, parseErr := strconv.Atoi(port)
				if err != nil || parseErr != nil || number < 1 || number > 65535 || !validListenHost(host) {
					return failure("invalid_request")
				}
			}
			if spec.Kind == "cidr" {
				if _, _, err := net.ParseCIDR(text); err != nil {
					return failure("invalid_request")
				}
			}
		}
	}
	return nil
}

func (a *app) queueSettings(ctx context.Context, changes map[string]any, lock *os.File) (any, error) {
	if _, err := a.account(); err != nil {
		return nil, err
	}
	if err := validateSettings(changes); err != nil {
		return nil, err
	}
	if err := writeJSON(filepath.Join(a.runDir, "settings-job.json"), changes); err != nil {
		return nil, failure("storage_error")
	}
	return a.startJob("apply_settings", lock)
}

func (a *app) applySettings(ctx context.Context) error {
	path := filepath.Join(a.runDir, "settings-job.json")
	defer os.Remove(path)
	var changes map[string]any
	if readJSON(path, &changes) != nil {
		return failure("storage_error")
	}
	if err := validateSettings(changes); err != nil {
		return err
	}
	candidate, local, err := a.stageProfileSettings(ctx, changes)
	if err != nil {
		return err
	}
	encoded, err := a.encodeProfileSettings(local)
	if err != nil {
		return err
	}
	if previous, err := os.ReadFile(a.profile); err == nil && bytes.Equal(previous, candidate) {
		if err := writePrivate(filepath.Join(a.dataDir, "settings.json"), encoded); err != nil {
			return failure("storage_error")
		}
		return nil
	}
	return a.replaceProfile(ctx, map[string][]byte{
		a.profile: candidate,
		filepath.Join(a.dataDir, "settings.json"): encoded,
	}, a.core.wanted.Load())
}
