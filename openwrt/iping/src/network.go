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
	"strings"
	"syscall"
	"time"
)

const firewallInclude = "/etc/nftables.d/0-mihomo-auto-redirect.nft"

type networkLease struct {
	Device      string `json:"device"`
	Backend     string `json:"backend,omitempty"`
	IPv6        bool   `json:"ipv6,omitempty"`
	IPTables4   string `json:"iptables4,omitempty"`
	IPTables6   string `json:"iptables6,omitempty"`
	IfIndex     int    `json:"ifindex,omitempty"`
	TableHandle uint64 `json:"table_handle,omitempty"`
	IncludeHash string `json:"include_hash,omitempty"`
	Boot        string `json:"boot,omitempty"`
}

func (a *app) leasePath() string { return filepath.Join(a.dataDir, "network.json") }

// The firewall include survives a reboot; the interface and table numbers do not.
func (a *app) readLease() (networkLease, error) {
	var lease networkLease
	if err := readJSON(a.leasePath(), &lease); err != nil {
		return lease, err
	}
	if lease.Boot != a.bootID() {
		lease.IfIndex, lease.TableHandle = 0, 0
		lease.IPTables4, lease.IPTables6 = "", ""
	}
	return lease, nil
}

func (a *app) bootID() string {
	data, _ := os.ReadFile(a.bootIDFile)
	return strings.TrimSpace(string(data))
}

func (a *app) networkIdentity(ctx context.Context, lease networkLease) (networkLease, error) {
	identity := networkLease{Device: lease.Device, Backend: lease.Backend, IPv6: lease.IPv6, Boot: a.bootID()}
	if lease.Backend == iptablesBackend {
		var err error
		identity.IPTables4, err = a.iptablesRules(ctx, "iptables")
		if err != nil {
			return identity, err
		}
		if lease.IPv6 {
			identity.IPTables6, err = a.iptablesRules(ctx, "ip6tables")
			if err != nil {
				return identity, err
			}
		}
	} else if lease.Backend == "" || lease.Backend == nftablesBackend {
		if err := a.nftablesIdentity(ctx, &identity); err != nil {
			return identity, err
		}
	} else {
		return identity, failure("service_failed")
	}
	data, err := a.command(ctx, "ip", "-j", "link", "show")
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
		if link.Name == lease.Device {
			identity.IfIndex = link.Index
		}
	}
	if lease.Backend != iptablesBackend {
		if data, err := os.ReadFile(a.firewallPath()); err == nil {
			hash := sha256.Sum256(data)
			identity.IncludeHash = hex.EncodeToString(hash[:])
		} else if !os.IsNotExist(err) {
			return identity, failure("service_failed")
		}
	}
	return identity, nil
}

func (a *app) nftablesIdentity(ctx context.Context, identity *networkLease) error {
	data, err := a.command(ctx, "nft", "-j", "-a", "list", "tables")
	if err != nil {
		return failure("service_failed")
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
		return failure("service_failed")
	}
	for _, entry := range tables.Nftables {
		if entry.Table.Family == "inet" && entry.Table.Name == "mihomo" {
			identity.TableHandle = entry.Table.Handle
		}
	}
	return nil
}

func (a *app) networkReady(ctx context.Context) error {
	lease, err := a.readLease()
	if errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return failure("service_failed")
	}
	identity, err := a.networkIdentity(ctx, lease)
	if err != nil {
		return err
	}
	if lease.IfIndex != 0 && identity.IfIndex != lease.IfIndex || lease.TableHandle != 0 && identity.TableHandle != lease.TableHandle {
		return failure("service_conflict")
	}
	if lease.Backend == iptablesBackend && iptablesReady(lease) {
		if !iptablesOwned(identity.IPTables4, lease.IPTables4) || !iptablesOwned(identity.IPTables6, lease.IPTables6) {
			return failure("service_conflict")
		}
		if identity.IPTables4 != lease.IPTables4 || identity.IPTables6 != lease.IPTables6 {
			return failure("service_failed")
		}
	}
	if identity != lease {
		if err := writeJSON(a.leasePath(), identity); err != nil {
			return failure("storage_error")
		}
	}
	if identity.IfIndex == 0 || identity.Backend == iptablesBackend && !iptablesReady(identity) || identity.Backend != iptablesBackend && identity.TableHandle == 0 {
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

func (a *app) acquireNetwork(ctx context.Context, device string, ipv6 bool) error {
	if err := a.cleanNetwork(ctx); err != nil {
		return err
	}
	backend, err := a.detectFirewall(ctx)
	if err != nil {
		return err
	}
	lease := networkLease{Device: device, Backend: backend, IPv6: backend == iptablesBackend && ipv6, Boot: a.bootID()}
	identity, err := a.networkIdentity(ctx, lease)
	if err != nil {
		return err
	}
	if identity.TableHandle != 0 || identity.IfIndex != 0 || identity.IncludeHash != "" || identity.IPTables4 != "" || identity.IPTables6 != "" {
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
	return writeJSON(a.leasePath(), lease)
}

func (a *app) cleanNetwork(ctx context.Context) error {
	lease, err := a.readLease()
	if errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil || !tunName.MatchString(lease.Device) {
		return failure("service_failed")
	}
	identity, err := a.networkIdentity(ctx, lease)
	if err != nil {
		return err
	}
	if identity.IfIndex != 0 && identity.IfIndex != lease.IfIndex || identity.TableHandle != 0 && identity.TableHandle != lease.TableHandle || identity.IncludeHash != "" && identity.IncludeHash != lease.IncludeHash || !iptablesOwned(identity.IPTables4, lease.IPTables4) || !iptablesOwned(identity.IPTables6, lease.IPTables6) {
		return failure("service_conflict")
	}
	if identity.Backend == iptablesBackend {
		if err := a.cleanIPTables(ctx, "iptables", identity.IPTables4); err != nil {
			return err
		}
		if err := a.cleanIPTables(ctx, "ip6tables", identity.IPTables6); err != nil {
			return err
		}
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
	if identity.Backend != iptablesBackend {
		if err := a.cleanFirewallInclude(ctx); err != nil {
			return err
		}
	}
	if remaining, err := a.networkIdentity(ctx, lease); err != nil || remaining.TableHandle != 0 || remaining.IfIndex != 0 || remaining.IPTables4 != "" || remaining.IPTables6 != "" {
		return failure("service_failed")
	}
	return os.Remove(a.leasePath())
}

func (a *app) cleanFirewallInclude(ctx context.Context) error {
	if err := os.Remove(a.firewallPath()); err == nil {
		if _, err := a.command(ctx, "fw4", "reload"); err != nil {
			return failure("service_failed")
		}
	} else if !os.IsNotExist(err) {
		return failure("service_failed")
	}
	return nil
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
