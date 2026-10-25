package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"go.yaml.in/yaml/v3"
)

const (
	routeTable   = 39200
	ruleStart    = 9200
	ruleEnd      = 9210
	fallbackRule = 39200
)

var tunName = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_-]{0,14}$`)

func (a *app) controllerSecret() (string, error) {
	path := filepath.Join(a.dataDir, "controller-secret")
	data, err := os.ReadFile(path)
	if err == nil && len(data) == 64 {
		return string(data), nil
	}
	if err != nil && !os.IsNotExist(err) {
		return "", failure("storage_error")
	}
	var secret [32]byte
	if _, err := rand.Read(secret[:]); err != nil {
		return "", failure("storage_error")
	}
	value := hex.EncodeToString(secret[:])
	if writePrivate(path, []byte(value)) != nil {
		return "", failure("storage_error")
	}
	return value, nil
}

func (a *app) buildProfile(source []byte, settings map[string]any) ([]byte, error) {
	var config map[string]any
	if yaml.Unmarshal(source, &config) != nil || config == nil {
		return nil, failure("invalid_subscription")
	}
	for key, spec := range settingsSpec {
		if !strings.HasPrefix(key, "custom.") && yamlSetting(config, key) == nil {
			setYAMLSetting(config, key, spec.Default)
		}
	}
	data, err := yaml.Marshal(config)
	if err != nil {
		return nil, failure("invalid_request")
	}
	data, err = applyProfileSettings(data, settings)
	if err != nil {
		return nil, err
	}
	config = nil
	if yaml.Unmarshal(data, &config) != nil || config == nil {
		return nil, failure("invalid_request")
	}
	for _, key := range []string{"tun.enable", "tun.device", "dns.enable", "dns.listen"} {
		value := settingsSpec[key].Default
		if saved, ok := settings[key]; ok {
			value = saved
		}
		setYAMLSetting(config, key, value)
	}
	device, _ := yamlSetting(config, "tun.device").(string)
	if !tunName.MatchString(device) {
		return nil, failure("invalid_request")
	}
	enabled := yamlSetting(config, "tun.enable") == true
	if enabled && (yamlSetting(config, "dns.enable") != true || len(stringList(yamlSetting(config, "tun.dns-hijack"))) == 0) {
		return nil, failure("invalid_request")
	}
	for key, value := range map[string]any{
		"tun.auto-route":                                 true,
		"tun.auto-redirect":                              true,
		"tun.auto-detect-interface":                      true,
		"tun.strict-route":                               false,
		"tun.iproute2-table-index":                       routeTable,
		"tun.iproute2-rule-index":                        ruleStart,
		"tun.auto-redirect-iproute2-fallback-rule-index": fallbackRule,
		"tun.auto-redirect-input-mark":                   0x4950,
		"tun.auto-redirect-output-mark":                  0x4951,
	} {
		setYAMLSetting(config, key, value)
	}
	tun := config["tun"].(map[string]any)
	delete(tun, "file-descriptor")
	listeners := []any{}
	for _, entry := range configList(config["listeners"]) {
		if listener, ok := entry.(map[string]any); ok && listener["type"] != "tun" {
			listeners = append(listeners, listener)
		}
	}
	if len(listeners) > 0 {
		config["listeners"] = listeners
	} else {
		delete(config, "listeners")
	}
	delete(config, "iptables")
	secret, err := a.controllerSecret()
	if err != nil {
		return nil, err
	}
	for _, key := range []string{
		"external-controller-tls", "external-controller-unix", "external-controller-pipe",
		"external-ui", "external-ui-url", "external-ui-name", "routing-mark", "interface-name",
	} {
		delete(config, key)
	}
	config["external-controller"], config["secret"] = a.controllerAddress, secret
	_, controlPort, err := net.SplitHostPort(a.controllerAddress)
	if err != nil {
		return nil, failure("invalid_request")
	}
	controlNumber, err := strconv.Atoi(controlPort)
	if err != nil {
		return nil, failure("invalid_request")
	}
	ports := map[int]bool{controlNumber: true}
	for _, key := range []string{"mixed-port", "port", "socks-port", "redir-port", "tproxy-port"} {
		number, err := strconv.Atoi(fmt.Sprint(config[key]))
		if err != nil || number < 0 || number > 65535 || number != 0 && ports[number] {
			return nil, failure("invalid_request")
		}
		ports[number] = number != 0
	}
	if yamlSetting(config, "dns.enable") == true {
		_, dnsPort, err := net.SplitHostPort(fmt.Sprint(yamlSetting(config, "dns.listen")))
		number, parseErr := strconv.Atoi(dnsPort)
		if err != nil || parseErr != nil || number < 1024 || number > 65535 || ports[number] {
			return nil, failure("invalid_request")
		}
	}
	return yaml.Marshal(config)
}

func (a *app) validateProfile(ctx context.Context, data []byte) error {
	staging, err := os.MkdirTemp(a.runDir, "validate-*")
	if err != nil {
		return failure("storage_error")
	}
	defer os.RemoveAll(staging)
	path := filepath.Join(staging, "config.yaml")
	if writePrivate(path, data) != nil {
		return failure("storage_error")
	}
	if _, err := a.command(ctx, a.coreBinary, "-t", "-d", a.dataDir, "-f", path); err != nil {
		return failure("invalid_request")
	}
	return nil
}

func configList(value any) []any { items, _ := value.([]any); return items }
