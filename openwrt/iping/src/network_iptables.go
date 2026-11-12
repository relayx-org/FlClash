package main

import (
	"context"
	"os"
	"strconv"
	"strings"
)

const (
	nftablesBackend = "nftables"
	iptablesBackend = "iptables"
)

// These chains belong to sing-tun v0.4.27, pinned by the packaged Mihomo.
var iptablesChains = []struct{ table, name, hook string }{
	{"nat", "mihomo-output", "OUTPUT"},
	{"nat", "mihomo-prerouting", "PREROUTING"},
	{"filter", "mihomo-input", "INPUT"},
	{"filter", "mihomo-forward", "FORWARD"},
}

func (a *app) detectFirewall(ctx context.Context) (string, error) {
	if a.hostConfig == "" {
		if _, err := a.command(ctx, "fw4", "-q", "print"); err == nil {
			return nftablesBackend, nil
		}
		if _, err := a.command(ctx, "fw3", "-q", "print"); err == nil {
			return iptablesBackend, nil
		}
		if _, err := a.command(ctx, "iptables", "-w", "2", "-t", "nat", "-S"); err == nil {
			return iptablesBackend, nil
		}
	}
	if _, err := a.command(ctx, "nft", "-j", "list", "tables"); err != nil {
		return "", failure("service_failed")
	}
	return nftablesBackend, nil
}

func coreEnvironment(backend string) []string {
	env := []string{}
	for _, value := range os.Environ() {
		if !strings.HasPrefix(value, "DISABLE_NFTABLES=") {
			env = append(env, value)
		}
	}
	return append(env, "DISABLE_NFTABLES="+strconv.FormatBool(backend == iptablesBackend))
}

func (a *app) iptablesRules(ctx context.Context, binary string) (string, error) {
	var rules []string
	for _, table := range []string{"nat", "filter"} {
		data, err := a.command(ctx, binary, "-w", "2", "-t", table, "-S")
		if err != nil {
			return "", failure("service_failed")
		}
		for _, line := range strings.Split(string(data), "\n") {
			fields := strings.Fields(line)
			if len(fields) < 2 {
				continue
			}
			owned := false
			for _, chain := range iptablesChains {
				if chain.table != table {
					continue
				}
				if fields[1] == chain.name && (fields[0] == "-N" || fields[0] == "-A") {
					owned = true
				}
				for i := 2; i+1 < len(fields); i++ {
					if (fields[i] == "-j" || fields[i] == "-g") && fields[i+1] == chain.name {
						if line != "-A "+chain.hook+" -j "+chain.name {
							return "", failure("service_conflict")
						}
						owned = true
					}
				}
			}
			if owned {
				rules = append(rules, table+" "+line)
			}
		}
	}
	return strings.Join(rules, "\n"), nil
}

func iptablesReady(lease networkLease) bool {
	return iptablesFamilyReady(lease.IPTables4) && (!lease.IPv6 || iptablesFamilyReady(lease.IPTables6))
}

func iptablesFamilyReady(rules string) bool {
	lines := "\n" + rules + "\n"
	for _, chain := range iptablesChains {
		if !strings.Contains(lines, "\n"+chain.table+" -N "+chain.name+"\n") ||
			!strings.Contains(lines, "\n"+chain.table+" -A "+chain.hook+" -j "+chain.name+"\n") ||
			!strings.Contains(lines, "\n"+chain.table+" -A "+chain.name+" ") {
			return false
		}
	}
	return true
}

func iptablesOwned(current, owned string) bool {
	if current == "" {
		return true
	}
	// Firewall reloads and Core shutdown can remove only part of the recorded rules.
	remaining := strings.Split(current, "\n")
	for _, line := range strings.Split(owned, "\n") {
		if line == remaining[0] {
			remaining = remaining[1:]
			if len(remaining) == 0 {
				return true
			}
		}
	}
	return false
}

func (a *app) cleanIPTables(ctx context.Context, binary, rules string) error {
	lines := "\n" + rules + "\n"
	for _, chain := range iptablesChains {
		if strings.Contains(lines, "\n"+chain.table+" -A "+chain.hook+" -j "+chain.name+"\n") {
			if _, err := a.command(ctx, binary, "-w", "2", "-t", chain.table, "-D", chain.hook, "-j", chain.name); err != nil {
				return failure("service_failed")
			}
		}
		if strings.Contains(lines, "\n"+chain.table+" -N "+chain.name+"\n") {
			for _, action := range []string{"-F", "-X"} {
				if _, err := a.command(ctx, binary, "-w", "2", "-t", chain.table, action, chain.name); err != nil {
					return failure("service_failed")
				}
			}
		}
	}
	return nil
}
