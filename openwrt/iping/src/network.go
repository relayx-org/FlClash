package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
	"time"
)

const firewallInclude = "/etc/nftables.d/0-mihomo-auto-redirect.nft"

type networkLease struct {
	Device      string `json:"device"`
	IfIndex     int    `json:"ifindex,omitempty"`
	TableHandle uint64 `json:"table_handle,omitempty"`
	IncludeHash string `json:"include_hash,omitempty"`
}

func (a *app) networkIdentity(ctx context.Context, device string) (networkLease, error) {
	identity := networkLease{Device: device}
	data, err := a.command(ctx, "nft", "-j", "-a", "list", "tables")
	if err != nil {
		return identity, failure("service_failed")
	}
	var tables struct {
		Nftables []struct {
			Table struct {
				Family string `json:"family"`
				Name   string `json:"name"`
				Handle uint64 `json:"handle"`
			} `json:"table"`
		} `json:"nftables"`
	}
	if json.Unmarshal(data, &tables) != nil {
		return identity, failure("service_failed")
	}
	for _, entry := range tables.Nftables {
		if entry.Table.Family == "inet" && entry.Table.Name == "mihomo" {
			identity.TableHandle = entry.Table.Handle
		}
	}
	data, err = a.command(ctx, "ip", "-j", "link", "show")
	if err != nil {
		return identity, failure("service_failed")
	}
	var links []struct {
		Name  string `json:"ifname"`
		Index int    `json:"ifindex"`
	}
	if json.Unmarshal(data, &links) != nil {
		return identity, failure("service_failed")
	}
	for _, link := range links {
		if link.Name == device {
			identity.IfIndex = link.Index
		}
	}
	if data, err := os.ReadFile(firewallInclude); err == nil {
		hash := sha256.Sum256(data)
		identity.IncludeHash = hex.EncodeToString(hash[:])
	} else if !os.IsNotExist(err) {
		return identity, failure("service_failed")
	}
	return identity, nil
}

func (a *app) networkReady(ctx context.Context) error {
	path := filepath.Join(a.runDir, "network.json")
	var lease networkLease
	if err := readJSON(path, &lease); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return failure("service_failed")
	}
	identity, err := a.networkIdentity(ctx, lease.Device)
	if err != nil {
		return err
	}
	if lease.IfIndex != 0 && identity.IfIndex != lease.IfIndex || lease.TableHandle != 0 && identity.TableHandle != lease.TableHandle {
		return failure("service_conflict")
	}
	if err := writeJSON(path, identity); err != nil {
		return failure("storage_error")
	}
	if identity.IfIndex == 0 || identity.TableHandle == 0 {
		return failure("service_failed")
	}
	return nil
}

type routeRule struct {
	Priority int `json:"priority"`
}

func ownedRule(priority int) bool {
	return priority >= ruleStart && priority <= ruleEnd || priority == fallbackRule
}

func (a *app) routeRules(ctx context.Context, family string) ([]routeRule, error) {
	data, err := a.command(ctx, "ip", family, "-j", "rule", "show")
	if err != nil {
		return nil, err
	}
	var rules []routeRule
	err = json.Unmarshal(data, &rules)
	return rules, err
}

func (a *app) acquireNetwork(ctx context.Context, device string) error {
	if err := a.cleanNetwork(ctx); err != nil {
		return err
	}
	identity, err := a.networkIdentity(ctx, device)
	if err != nil {
		return failure("service_failed")
	}
	if identity.TableHandle != 0 || identity.IfIndex != 0 || identity.IncludeHash != "" {
		return failure("service_conflict")
	}
	for _, family := range []string{"-4", "-6"} {
		rules, err := a.routeRules(ctx, family)
		if err != nil {
			return failure("service_failed")
		}
		for _, rule := range rules {
			if ownedRule(rule.Priority) {
				return failure("service_conflict")
			}
		}
		if routes, _ := a.command(ctx, "ip", family, "route", "show", "table", strconv.Itoa(routeTable)); len(routes) != 0 {
			return failure("service_conflict")
		}
	}
	return writeJSON(filepath.Join(a.runDir, "network.json"), networkLease{Device: device})
}

func (a *app) cleanNetwork(ctx context.Context) error {
	path := filepath.Join(a.runDir, "network.json")
	var lease networkLease
	if err := readJSON(path, &lease); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil || !tunName.MatchString(lease.Device) {
		return failure("service_failed")
	}
	identity, err := a.networkIdentity(ctx, lease.Device)
	if err != nil {
		return err
	}
	if identity.IfIndex != 0 && identity.IfIndex != lease.IfIndex || identity.TableHandle != 0 && identity.TableHandle != lease.TableHandle || identity.IncludeHash != "" && identity.IncludeHash != lease.IncludeHash {
		return failure("service_conflict")
	}
	if identity.TableHandle != 0 {
		if _, err := a.command(ctx, "nft", "delete", "table", "inet", "mihomo"); err != nil {
			return failure("service_failed")
		}
	}
	if identity.IfIndex != 0 {
		if _, err := a.command(ctx, "ip", "link", "delete", "dev", lease.Device); err != nil {
			return failure("service_failed")
		}
	}
	for _, family := range []string{"-4", "-6"} {
		rules, err := a.routeRules(ctx, family)
		if err != nil {
			return failure("service_failed")
		}
		for _, rule := range rules {
			if ownedRule(rule.Priority) {
				if _, err := a.command(ctx, "ip", family, "rule", "del", "pref", strconv.Itoa(rule.Priority)); err != nil {
					return failure("service_failed")
				}
			}
		}
		_, _ = a.command(ctx, "ip", family, "route", "flush", "table", strconv.Itoa(routeTable))
	}
	if err := os.Remove(firewallInclude); err == nil {
		if _, err := a.command(ctx, "fw4", "reload"); err != nil {
			return failure("service_failed")
		}
	} else if !os.IsNotExist(err) {
		return failure("service_failed")
	}
	if remaining, err := a.networkIdentity(ctx, lease.Device); err != nil || remaining.TableHandle != 0 || remaining.IfIndex != 0 {
		return failure("service_failed")
	}
	return os.Remove(path)
}

func (a *app) lockService(ctx context.Context, wait bool) (*os.File, error) {
	lock, err := os.OpenFile(filepath.Join(a.runDir, "service.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	for {
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return lock, nil
		}
		if !wait || err != syscall.EWOULDBLOCK {
			lock.Close()
			return nil, failure("busy")
		}
		select {
		case <-ctx.Done():
			lock.Close()
			return nil, failure("busy")
		case <-time.After(100 * time.Millisecond):
		}
	}
}
