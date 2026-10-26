package main

import (
	"context"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

func (a *app) configValue(ctx context.Context, key string) (string, error) {
	if a.hostConfig == "" {
		data, err := a.command(ctx, "/sbin/uci", "-q", "get", "iping.config."+key)
		return strings.TrimSpace(string(data)), err
	}
	values := map[string]string{}
	if err := readJSON(a.hostConfig, &values); err != nil {
		return "", err
	}
	value, ok := values[key]
	if !ok {
		return "", os.ErrNotExist
	}
	return value, nil
}

func (a *app) setConfigValue(ctx context.Context, key, value string) error {
	if a.hostConfig == "" {
		if _, err := a.command(ctx, "/sbin/uci", "set", "iping.config."+key+"="+value); err != nil {
			return failure("service_failed")
		}
		if _, err := a.command(ctx, "/sbin/uci", "commit", "iping"); err != nil {
			_, _ = a.command(ctx, "/sbin/uci", "revert", "iping")
			return failure("service_failed")
		}
		return nil
	}
	lock, err := os.OpenFile(filepath.Join(a.dataDir, "config.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return failure("storage_error")
	}
	defer lock.Close()
	for {
		if ctx.Err() != nil {
			return failure("interrupted")
		}
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			break
		}
		if err != syscall.EWOULDBLOCK {
			return failure("storage_error")
		}
		select {
		case <-ctx.Done():
			return failure("interrupted")
		case <-time.After(25 * time.Millisecond):
		}
	}
	values := map[string]string{}
	if err := readJSON(a.hostConfig, &values); err != nil && !errors.Is(err, os.ErrNotExist) {
		return failure("storage_error")
	}
	if ctx.Err() != nil {
		return failure("interrupted")
	}
	values[key] = value
	if writeJSON(a.hostConfig, values) != nil {
		return failure("storage_error")
	}
	return nil
}

func (a *app) localAddress(ctx context.Context) string {
	if a.hostConfig == "" {
		address, _ := a.command(ctx, "/sbin/uci", "-q", "get", "network.lan.ipaddr")
		ip := strings.Split(strings.TrimSpace(string(address)), "/")[0]
		if net.ParseIP(ip) != nil {
			return ip
		}
		return ""
	}
	addresses, _ := net.InterfaceAddrs()
	for _, address := range addresses {
		ip, _, err := net.ParseCIDR(address.String())
		if err == nil && ip.IsPrivate() && ip.To4() != nil {
			return ip.String()
		}
	}
	return ""
}

func (a *app) firewallPath() string {
	if a.hostConfig != "" {
		return ""
	}
	return firewallInclude
}
