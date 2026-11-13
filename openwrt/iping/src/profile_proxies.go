package main

import (
	"os"
	"sort"
	"strings"

	"go.yaml.in/yaml/v3"
)

type profileProxy struct {
	Name string `yaml:"name"`
	Type string `yaml:"type"`
}

type profileProxyGroup struct {
	profileProxy      `yaml:",inline"`
	Proxies           []string `yaml:"proxies"`
	Hidden            bool     `yaml:"hidden"`
	Icon              string   `yaml:"icon"`
	IncludeAll        bool     `yaml:"include-all"`
	IncludeAllProxies bool     `yaml:"include-all-proxies"`
	Filter            string   `yaml:"filter"`
}

type proxyProfile struct {
	Mode    string              `yaml:"mode"`
	Proxies []profileProxy      `yaml:"proxies"`
	Groups  []profileProxyGroup `yaml:"proxy-groups"`
}

func readProxyProfile(path string) (proxyProfile, error) {
	var config proxyProfile
	data, err := os.ReadFile(path)
	if err != nil || yaml.Unmarshal(data, &config) != nil {
		return config, failure("storage_error")
	}
	return config, nil
}

func profileProxyType(kind string) string {
	switch kind {
	case "select":
		return "Selector"
	case "url-test":
		return "URLTest"
	case "load-balance":
		return "LoadBalance"
	case "ss":
		return "Shadowsocks"
	case "ssr":
		return "ShadowsocksR"
	case "wireguard":
		return "WireGuard"
	case "anytls":
		return "AnyTLS"
	}
	if kind == "" {
		return "Unknown"
	}
	return strings.ToUpper(kind[:1]) + kind[1:]
}

func (config proxyProfile) proxyMap() (map[string]proxyData, error) {
	proxies := map[string]proxyData{
		"DIRECT": {Name: "DIRECT", Type: "Direct"},
		"REJECT": {Name: "REJECT", Type: "Reject"},
	}
	names := []string{"DIRECT", "REJECT"}
	all := []string{}
	for _, node := range config.Proxies {
		proxies[node.Name] = proxyData{Name: node.Name, Type: profileProxyType(node.Type)}
		names = append(names, node.Name)
		all = append(all, node.Name)
	}
	sort.Strings(all)
	for _, group := range config.Groups {
		members := append([]string{}, group.Proxies...)
		if group.IncludeAll || group.IncludeAllProxies {
			parts, err := compileResourceFilter(group.Filter)
			if err != nil {
				return nil, failure("invalid_subscription")
			}
			filter := resourceFilter{parts: parts}
			for _, name := range all {
				matched, err := filter.matches(name)
				if err != nil {
					return nil, failure("invalid_subscription")
				}
				if matched {
					members = append(members, name)
				}
			}
		}
		proxies[group.Name] = proxyData{Name: group.Name, Type: profileProxyType(group.Type), All: members, Hidden: group.Hidden, Icon: group.Icon}
		names = append(names, group.Name)
	}
	if _, configured := proxies["GLOBAL"]; !configured {
		proxies["GLOBAL"] = proxyData{Name: "GLOBAL", Type: "Selector", All: names}
	}
	return proxies, nil
}
