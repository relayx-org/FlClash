package main

import (
	"net"
	"regexp"
	"strings"
)

var listenHostLabel = regexp.MustCompile(`^[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?$`)

func validListenHost(host string) bool {
	if host == "" || net.ParseIP(host) != nil {
		return true
	}
	if len(host) > 253 {
		return false
	}
	for _, label := range strings.Split(host, ".") {
		if !listenHostLabel.MatchString(label) {
			return false
		}
	}
	return true
}

func isScopedSetting(key string) bool {
	_, exists := settingsSpec[key]
	return exists && (strings.HasPrefix(key, "dns.") || strings.HasPrefix(key, "tun."))
}

func ownedSetting(key string) bool {
	switch key {
	case "tun.enable", "tun.device", "dns.enable", "dns.listen":
		return true
	}
	return false
}
