package main

import "strings"

type resourceRule struct{ ID, Value string }

func resourceRules(value any) ([]resourceRule, error) {
	entries, err := resourceEntries(value)
	if err != nil {
		return nil, err
	}
	result := []resourceRule{}
	for _, entry := range entries {
		definition, ok := entry["definition"].(map[string]any)
		if !ok || len(entry) != 2 || len(definition) != 7 {
			return nil, failure("invalid_request")
		}
		for _, key := range []string{"ruleAction", "content", "ruleTarget", "ruleProvider", "subRule", "noResolve", "src"} {
			if _, exists := definition[key]; !exists {
				return nil, failure("invalid_request")
			}
		}
		rawAction, ok := definition["ruleAction"].(string)
		action := strings.ReplaceAll(rawAction, "_", "-")
		if !ok || !resourceRuleActions[action] {
			return nil, failure("invalid_request")
		}
		fields := map[string]string{}
		for _, key := range []string{"content", "ruleTarget", "ruleProvider", "subRule"} {
			if definition[key] == nil {
				continue
			}
			text, ok := definition[key].(string)
			if !ok || !resourceText(text, 2048) {
				return nil, failure("invalid_request")
			}
			fields[key] = text
		}
		noResolve, noResolveOK := definition["noResolve"].(bool)
		src, srcOK := definition["src"].(bool)
		if !noResolveOK || !srcOK {
			return nil, failure("invalid_request")
		}
		payload := fields["content"]
		target := fields["ruleTarget"]
		if action == "RULE-SET" {
			payload = fields["ruleProvider"]
		}
		if action == "SUB-RULE" {
			target = fields["subRule"]
		}
		if target == "" || action != "MATCH" && payload == "" {
			return nil, failure("invalid_request")
		}
		parts := []string{action}
		if action != "MATCH" {
			parts = append(parts, payload)
		}
		parts = append(parts, target)
		switch action {
		case "GEOIP", "IP-ASN", "IP-CIDR", "IP-CIDR6", "IP-SUFFIX", "RULE-SET":
			if src {
				parts = append(parts, "src")
			}
			if noResolve {
				parts = append(parts, "no-resolve")
			}
		}
		line := strings.Join(parts, ",")
		if len(line) > 2048 {
			return nil, failure("invalid_request")
		}
		result = append(result, resourceRule{entry["id"].(string), line})
	}
	return result, nil
}

func applyResourceRules(config map[string]any, rules []resourceRule, selected map[string]bool) {
	existing, _ := config["rules"].([]any)
	target := ""
	for index := len(existing) - 1; index >= 0; index-- {
		text, ok := existing[index].(string)
		if !ok {
			continue
		}
		parts := strings.Split(text, ",")
		if len(parts) >= 2 && strings.EqualFold(strings.TrimSpace(parts[0]), "MATCH") {
			target = strings.TrimSpace(parts[1])
			break
		}
	}
	added := []any{}
	for _, rule := range rules {
		if !selected[rule.ID] {
			continue
		}
		value := rule.Value
		parts := strings.Split(value, ",")
		end := len(parts) - 1
		for end > 0 && (strings.TrimSpace(parts[end]) == "no-resolve" || strings.TrimSpace(parts[end]) == "src") {
			end--
		}
		if target != "" && strings.EqualFold(strings.TrimSpace(parts[end]), "MATCH") {
			parts[end] = target
			value = strings.Join(parts, ",")
		}
		added = append(added, value)
	}
	if len(added) > 0 {
		config["rules"] = append(added, existing...)
	}
}

var resourceRuleActions = func() map[string]bool {
	result := map[string]bool{}
	for _, action := range strings.Fields(`DOMAIN DOMAIN-SUFFIX DOMAIN-KEYWORD DOMAIN-REGEX DOMAIN-WILDCARD GEOSITE IP-CIDR IP-CIDR6 IP-SUFFIX IP-ASN GEOIP SRC-GEOIP SRC-IP-ASN SRC-IP-CIDR SRC-IP-SUFFIX DST-PORT SRC-PORT IN-PORT IN-TYPE IN-USER IN-NAME REMATCH-NAME PROCESS-PATH PROCESS-PATH-REGEX PROCESS-PATH-WILDCARD PROCESS-NAME PROCESS-NAME-REGEX PROCESS-NAME-WILDCARD UID NETWORK DSCP RULE-SET AND OR NOT SUB-RULE MATCH`) {
		result[action] = true
	}
	return result
}()
