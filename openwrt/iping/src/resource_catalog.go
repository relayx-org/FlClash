package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/url"
	"path/filepath"
	"strings"
	"time"

	"go.yaml.in/yaml/v3"
)

func resourceText(value string, limit int) bool {
	return strings.TrimSpace(value) != "" && len(value) <= limit && !strings.ContainsAny(value, "\x00\r\n")
}

func resourceName(value string) bool {
	return resourceText(value, 255) && !strings.Contains(value, ",")
}

func resourceEntries(value any) ([]map[string]any, error) {
	result := []map[string]any{}
	if value == nil {
		return result, nil
	}
	items, ok := value.([]any)
	if !ok || len(items) > 128 {
		return nil, failure("invalid_request")
	}
	ids := map[string]bool{}
	for _, raw := range items {
		item, ok := raw.(map[string]any)
		if !ok {
			return nil, failure("invalid_request")
		}
		id, ok := item["id"].(string)
		if !ok || !resourceText(id, 128) || ids[id] {
			return nil, failure("invalid_request")
		}
		ids[id] = true
		result = append(result, item)
	}
	return result, nil
}

func resourceProxies(value any) ([]any, error) {
	entries, err := resourceEntries(value)
	if err != nil {
		return nil, err
	}
	result := []any{}
	names := map[string]bool{"DIRECT": true, "REJECT": true, "REJECT-DROP": true, "PASS": true, "COMPATIBLE": true, "GLOBAL": true}
	for _, item := range entries {
		proxy, ok := item["definition"].(map[string]any)
		if !ok || len(item) != 2 && len(item) != 3 {
			return nil, failure("invalid_request")
		}
		if options, exists := item["emptyOptions"]; exists {
			values, ok := options.([]any)
			if !ok || len(values) > len(resourceProxyFields) {
				return nil, failure("invalid_request")
			}
			seen := map[string]bool{}
			for _, value := range values {
				name, ok := value.(string)
				if !ok || !resourceProxyFields[name] || seen[name] {
					return nil, failure("invalid_request")
				}
				seen[name] = true
			}
		} else if len(item) == 3 {
			return nil, failure("invalid_request")
		}
		name, nameOK := proxy["name"].(string)
		kind, typeOK := proxy["type"].(string)
		data, err := json.Marshal(proxy)
		if !nameOK || !typeOK || !resourceName(name) || !resourceText(kind, 64) || names[name] || err != nil || len(data) > 32768 {
			return nil, failure("invalid_request")
		}
		names[name] = true
		result = append(result, proxy)
	}
	return result, nil
}

func resourceProviders(value any) (map[string]any, error) {
	entries, err := resourceEntries(value)
	if err != nil {
		return nil, err
	}
	result := map[string]any{}
	for _, item := range entries {
		label, labelOK := item["label"].(string)
		address, urlOK := item["url"].(string)
		behavior, behaviorOK := item["behavior"].(string)
		format, formatOK := item["format"].(string)
		u, err := url.Parse(address)
		if len(item) != 5 || !labelOK || !resourceName(label) || !urlOK || !resourceText(address, 2048) || err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Hostname() == "" || u.User != nil || u.Fragment != "" || !behaviorOK || !formatOK {
			return nil, failure("invalid_request")
		}
		if behavior != "classical" && behavior != "domain" && behavior != "ipcidr" || format != "yaml" && format != "text" && format != "mrs" || behavior == "classical" && format == "mrs" {
			return nil, failure("invalid_request")
		}
		if _, exists := result[label]; exists {
			return nil, failure("invalid_request")
		}
		result[label] = map[string]any{
			"type": "http", "url": address, "behavior": behavior, "format": format, "interval": 86400,
			"path": filepath.Join("rule-providers", fmt.Sprintf("iping-%x", sha256.Sum256([]byte(item["id"].(string)+"@"+address)))) + "." + format,
		}
	}
	return result, nil
}

func (a *app) validateResourceProxies(ctx context.Context, proxies []map[string]any) ([]string, error) {
	if len(proxies) > 128 {
		return nil, failure("invalid_request")
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	results := make([]string, len(proxies))
	for i, proxy := range proxies {
		if ctx.Err() != nil {
			return nil, failure("invalid_request")
		}
		if _, err := resourceProxies([]any{map[string]any{"id": "validation", "definition": proxy}}); err != nil {
			return nil, err
		}
		data, err := yaml.Marshal(map[string]any{
			"proxies": []any{proxy}, "rules": []string{"MATCH,DIRECT"},
			"dns": map[string]any{"enable": false}, "log-level": "silent",
		})
		if err != nil {
			return nil, failure("invalid_request")
		}
		if err := a.validateProfile(ctx, data); err != nil {
			results[i] = "invalid_proxy"
		}
	}
	return results, nil
}

var resourceProxyFields = func() map[string]bool {
	result := map[string]bool{}
	for _, name := range strings.Fields(`username password uuid psk key privateKey publicKey privateKeyPassphrase preSharedKey authStr cipher alterId protocol obfs transport up down network flow wsPath wsHost grpcServiceName xhttpPath xhttpHost tls sni servername alpn skipCertVerify clientFingerprint realityPublicKey realityShortId plugin pluginMode pluginHost udpOverTcp protocolParam obfsParam obfsPassword obfsSecret obfsMode obfsHost version ports hopInterval congestionController udpRelayMode reduceRtt ip ipv6 allowedIps dns remoteDnsResolve mtu tfo mptcp interfaceName routingMark ipVersion`) {
		result[name] = true
	}
	return result
}()

func validResourceURL(value any) bool {
	address, ok := value.(string)
	if !ok || !resourceText(address, 2048) {
		return false
	}
	u, err := url.Parse(address)
	return err == nil && (u.Scheme == "https" || u.Scheme == "http") && u.Hostname() != "" && u.User == nil && u.Fragment == ""
}
