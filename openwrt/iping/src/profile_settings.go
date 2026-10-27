package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dop251/goja"
	"go.yaml.in/yaml/v3"
)

var profileSettingsSpec = map[string]settingSpec{
	"mode":                           {Kind: "enum", Default: "rule", Choices: []string{"rule", "global", "direct"}},
	"global-ua":                      {Kind: "string", Default: "clash.meta", Max: 2048},
	"dns.ipv6-timeout":               {Kind: "int", Default: 100, Min: 0, Max: 10000},
	"dns.cache-max-size":             {Kind: "int", Default: 4096, Min: 1, Max: 1048576},
	"dns.fallback-lazy-query":        {Kind: "bool", Default: false},
	"dns.fallback-filter.geoip":      {Kind: "bool", Default: true},
	"dns.fallback-filter.geoip-code": {Kind: "string", Default: "CN", Max: 8},
	"dns.fallback-filter.geosite":    {Kind: "list", Default: []string{}, Max: 2048},
	"dns.fallback-filter.ipcidr":     {Kind: "list", Default: []string{}, Max: 2048},
	"dns.fallback-filter.domain":     {Kind: "list", Default: []string{}, Max: 2048},
	"custom.bindings":                {Kind: "bindings", Default: map[string]any{"proxies": []any{}, "providers": []any{}, "filters": []any{}, "rules": []any{}, "script": nil}},
	"custom.rules":                   {Kind: "rules", Default: []any{}, Max: 2048},
	"custom.proxies":                 {Kind: "proxies", Default: []any{}, Max: 32768},
	"custom.rule-providers":          {Kind: "providers", Default: []any{}, Max: 32768},
	"custom.filters":                 {Kind: "filters", Default: []any{}, Max: 4096},
	"custom.icons":                   {Kind: "map", Default: map[string]string{}, Max: 2048},
	"custom.scripts":                 {Kind: "scripts", Default: []any{}, Max: 131072},
}

func init() {
	for key, spec := range profileSettingsSpec {
		settingsSpec[key] = spec
	}
	for key, spec := range settingsSpec {
		profileSettingsSpec[key] = spec
	}
}

const resourceBindingsKey = "resource-bindings"

func (a *app) storedProfileSettings() (map[string]any, error) {
	values := map[string]any{}
	err := readJSON(filepath.Join(a.dataDir, "settings.json"), &values)
	if err != nil && !os.IsNotExist(err) {
		return nil, failure("storage_error")
	}
	return values, nil
}

func (a *app) profileSettings() (map[string]any, error) {
	id, _ := a.resourceProfileID()
	return a.profileSettingsFor(id)
}

func (a *app) profileSettingsFor(id string) (map[string]any, error) {
	values, err := a.storedProfileSettings()
	if err != nil {
		return nil, err
	}
	scopes, _ := values[resourceBindingsKey].(map[string]any)
	delete(values, resourceBindingsKey)
	delete(values, "custom.bindings")
	if bindings, exists := scopes[id]; exists {
		values["custom.bindings"] = bindings
	}
	return values, nil
}

func (a *app) encodeProfileSettings(values map[string]any) ([]byte, error) {
	stored, err := a.storedProfileSettings()
	if err != nil {
		return nil, err
	}
	scopes, _ := stored[resourceBindingsKey].(map[string]any)
	if scopes == nil {
		scopes = map[string]any{}
	}
	if bindings, exists := values["custom.bindings"]; exists {
		id, err := a.resourceProfileID()
		if err != nil {
			return nil, err
		}
		scopes[id] = bindings
	}
	next := map[string]any{resourceBindingsKey: scopes}
	for key, value := range values {
		if key != "custom.bindings" {
			next[key] = value
		}
	}
	return json.Marshal(next)
}

func setYAMLSetting(config map[string]any, path string, value any) {
	if path == "hosts" || path == "dns.nameserver-policy" || path == "dns.proxy-server-nameserver-policy" {
		if entries, ok := value.(map[string]any); ok {
			normalized := map[string]any{}
			for name, raw := range entries {
				if text, ok := raw.(string); ok {
					normalized[name] = strings.Split(text, ",")
				} else {
					normalized[name] = raw
				}
			}
			value = normalized
		}
	}
	keys := strings.Split(path, ".")
	for _, key := range keys[:len(keys)-1] {
		child, ok := config[key].(map[string]any)
		if !ok {
			child = map[string]any{}
			config[key] = child
		}
		config = child
	}
	config[keys[len(keys)-1]] = value
}

func applyProfileSettings(data []byte, values map[string]any) ([]byte, error) {
	if len(values) == 0 {
		return data, nil
	}
	var config map[string]any
	if yaml.Unmarshal(data, &config) != nil || config == nil {
		return nil, failure("invalid_subscription")
	}
	bindings, err := parseResourceBindings(values["custom.bindings"])
	if err != nil {
		return nil, err
	}
	scripts, err := resourceScripts(values["custom.scripts"])
	if err != nil {
		return nil, err
	}
	for _, script := range scripts {
		if script.ID == bindings.Script && strings.TrimSpace(script.Content) != "" {
			if config["proxy-providers"] == nil {
				config["proxy-providers"] = map[string]any{}
			}
			config, err = evaluateProfileScript(script.Content, config)
			if err != nil {
				return nil, err
			}
		}
	}
	for key, value := range values {
		if strings.HasPrefix(key, "custom.") {
			continue
		}
		if _, ok := profileSettingsSpec[key]; ok {
			// Mihomo refuses an empty primary nameserver, as on the native override path.
			if key == "dns.nameserver" && len(stringList(value)) == 0 {
				continue
			}
			setYAMLSetting(config, key, value)
		}
	}
	entries, err := resourceEntries(values["custom.proxies"])
	if err != nil {
		return nil, err
	}
	allProxies, err := resourceProxies(values["custom.proxies"])
	if err != nil {
		return nil, err
	}
	current, _ := config["proxies"].([]any)
	groups, _ := config["proxy-groups"].([]any)
	byName := map[string]any{}
	for _, raw := range append(append([]any{}, current...), groups...) {
		if object, ok := raw.(map[string]any); ok {
			if name, ok := object["name"].(string); ok {
				byName[name] = object
			}
		}
	}
	names := []string{}
	for index, entry := range entries {
		if !bindings.Proxies[entry["id"].(string)] {
			continue
		}
		proxy := allProxies[index].(map[string]any)
		name := proxy["name"].(string)
		if existing, exists := byName[name]; exists {
			left, _ := json.Marshal(existing)
			right, _ := json.Marshal(proxy)
			if string(left) != string(right) {
				return nil, failure("invalid_request")
			}
		} else {
			current = append(current, proxy)
			byName[name] = proxy
		}
		names = append(names, name)
	}
	filters, err := resourceFilters(values["custom.filters"])
	if err != nil {
		return nil, err
	}
	filterNames := map[string]bool{}
	for _, filter := range filters {
		if !bindings.Filters[filter.Label] {
			continue
		}
		if _, exists := byName[filter.Label]; exists {
			return nil, failure("invalid_request")
		}
		group := map[string]any{"name": filter.Label, "type": "select", "include-all-proxies": true, "include-all-providers": true, "filter": filter.Pattern}
		groups = append(groups, group)
		byName[filter.Label] = group
		names = append(names, filter.Label)
		filterNames[filter.Label] = true
	}
	for _, raw := range groups {
		group, ok := raw.(map[string]any)
		if !ok || group["type"] != "select" || filterNames[fmt.Sprint(group["name"])] {
			continue
		}
		members, _ := group["proxies"].([]any)
		seen := map[string]bool{}
		for _, raw := range members {
			if name, ok := raw.(string); ok {
				seen[name] = true
			}
		}
		for _, name := range names {
			if group["name"] != name && !seen[name] {
				members = append(members, name)
				seen[name] = true
			}
		}
		group["proxies"] = members
	}
	config["proxies"] = current
	config["proxy-groups"] = groups
	providers, err := resourceProviders(values["custom.rule-providers"])
	if err != nil {
		return nil, err
	}
	providerEntries, err := resourceEntries(values["custom.rule-providers"])
	if err != nil {
		return nil, err
	}
	if len(bindings.Providers) > 0 {
		current, ok := config["rule-providers"].(map[string]any)
		if !ok {
			current = map[string]any{}
		}
		for _, entry := range providerEntries {
			if bindings.Providers[entry["id"].(string)] {
				label := entry["label"].(string)
				if _, exists := current[label]; exists {
					return nil, failure("invalid_request")
				}
				current[label] = providers[label]
			}
		}
		config["rule-providers"] = current
	}
	if icons, ok := values["custom.icons"].(map[string]any); ok {
		if groups, ok := config["proxy-groups"].([]any); ok {
			for _, raw := range groups {
				if group, ok := raw.(map[string]any); ok {
					if icon, ok := icons[fmt.Sprint(group["name"])]; ok {
						group["icon"] = icon
					}
				}
			}
		}
	}
	rules, err := resourceRules(values["custom.rules"])
	if err != nil {
		return nil, err
	}
	applyResourceRules(config, rules, bindings.Rules)
	result, err := yaml.Marshal(config)
	if err != nil || len(result) > 8*1024*1024 {
		return nil, failure("invalid_request")
	}
	return result, nil
}

func evaluateProfileScript(script string, config map[string]any) (map[string]any, error) {
	vm := goja.New()
	vm.SetMaxCallStackSize(256)
	timer := time.AfterFunc(3*time.Second, func() { vm.Interrupt("timeout") })
	defer timer.Stop()
	_ = vm.Set("console", map[string]any{"log": func(...any) {}, "warn": func(...any) {}, "error": func(...any) {}, "info": func(...any) {}, "debug": func(...any) {}})
	if _, err := vm.RunString(script); err != nil {
		return nil, failure("invalid_request")
	}
	entry, err := vm.RunString("main")
	if err != nil {
		return nil, failure("invalid_request")
	}
	fn, ok := goja.AssertFunction(entry)
	if !ok {
		return nil, failure("invalid_request")
	}
	input, err := json.Marshal(config)
	if err != nil {
		return nil, failure("invalid_request")
	}
	parse, _ := goja.AssertFunction(vm.Get("JSON").ToObject(vm).Get("parse"))
	argument, err := parse(goja.Undefined(), vm.ToValue(string(input)))
	if err != nil {
		return nil, failure("invalid_request")
	}
	result, err := fn(goja.Undefined(), argument)
	if err != nil {
		return nil, failure("invalid_request")
	}
	if promise, ok := result.Export().(*goja.Promise); ok {
		if promise.State() != goja.PromiseStateFulfilled {
			return nil, failure("invalid_request")
		}
		result = promise.Result()
	}
	if goja.IsNull(result) || goja.IsUndefined(result) {
		return config, nil
	}
	stringify, _ := goja.AssertFunction(vm.Get("JSON").ToObject(vm).Get("stringify"))
	serialized, err := stringify(goja.Undefined(), result)
	var output map[string]any
	if err != nil || len(serialized.String()) > 8*1024*1024 || json.Unmarshal([]byte(serialized.String()), &output) != nil || output == nil {
		return nil, failure("invalid_request")
	}
	return output, nil
}

func (a *app) stageProfileSettings(ctx context.Context, changes map[string]any) ([]byte, map[string]any, error) {
	values, err := a.profileSettings()
	if err != nil {
		return nil, nil, err
	}
	for key, value := range changes {
		if value == nil && isScopedSetting(key) {
			delete(values, key)
		} else {
			values[key] = value
		}
	}
	if _, changed := changes["custom.bindings"]; changed {
		if err := validateBoundResources(values); err != nil {
			return nil, nil, err
		}
	}
	data, err := os.ReadFile(filepath.Join(a.dataDir, "source.yaml"))
	if err != nil {
		return nil, nil, failure("sync_required")
	}
	candidate, err := a.buildProfile(data, values)
	if err != nil {
		return nil, nil, err
	}
	if err := a.validateProfile(ctx, candidate); err != nil {
		return nil, nil, err
	}
	return candidate, values, nil
}
