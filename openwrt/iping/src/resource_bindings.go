package main

import (
	"strconv"
	"strings"
)

type resourceBindings struct {
	Proxies, Providers, Filters, Rules map[string]bool
	Script                             string
}

func parseResourceBindings(value any) (resourceBindings, error) {
	result := resourceBindings{Proxies: map[string]bool{}, Providers: map[string]bool{}, Filters: map[string]bool{}, Rules: map[string]bool{}}
	if value == nil {
		return result, nil
	}
	object, ok := value.(map[string]any)
	if !ok || len(object) != 5 {
		return result, failure("invalid_request")
	}
	for key, target := range map[string]map[string]bool{"proxies": result.Proxies, "providers": result.Providers, "filters": result.Filters, "rules": result.Rules} {
		items, ok := object[key].([]any)
		if !ok || len(items) > 128 {
			return result, failure("invalid_request")
		}
		for _, item := range items {
			text, ok := item.(string)
			if !ok || !resourceText(text, 256) || target[text] {
				return result, failure("invalid_request")
			}
			target[text] = true
		}
	}
	raw, exists := object["script"]
	if !exists {
		return result, failure("invalid_request")
	}
	if raw != nil {
		id, ok := raw.(string)
		if !ok || !resourceText(id, 128) {
			return result, failure("invalid_request")
		}
		result.Script = id
	}
	return result, nil
}

func (a *app) resourceProfileID() (string, error) {
	account, err := a.account()
	if err != nil {
		return "", err
	}
	return strings.TrimRight(account.Site, "/") + "/" + strconv.FormatInt(account.ID, 10), nil
}

func validateBoundResources(values map[string]any) error {
	bindings, err := parseResourceBindings(values["custom.bindings"])
	if err != nil {
		return err
	}
	for key, selected := range map[string]map[string]bool{
		"custom.proxies": bindings.Proxies, "custom.rule-providers": bindings.Providers,
		"custom.filters": bindings.Filters, "custom.rules": bindings.Rules,
		"custom.scripts": {bindings.Script: bindings.Script != ""},
	} {
		found := map[string]bool{}
		if key == "custom.filters" {
			filters, err := resourceFilters(values[key])
			if err != nil {
				return err
			}
			for _, filter := range filters {
				found[filter.Label] = true
			}
		} else {
			entries, err := resourceEntries(values[key])
			if err != nil {
				return err
			}
			for _, entry := range entries {
				found[entry["id"].(string)] = true
			}
		}
		for id, enabled := range selected {
			if enabled && !found[id] {
				return failure("resource_changed")
			}
		}
	}
	return nil
}
