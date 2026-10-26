package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

type failure string

func (e failure) Error() string { return string(e) }

type arguments struct {
	ProfileID        string           `json:"profile_id"`
	Changes          map[string]any   `json:"changes"`
	URL              string           `json:"url"`
	CloseConnections bool             `json:"close_connections"`
	Session          string           `json:"session"`
	RedirectURI      string           `json:"redirect_uri"`
	Code             string           `json:"code"`
	State            string           `json:"state"`
	Group            string           `json:"group"`
	Name             string           `json:"name"`
	Query            string           `json:"query"`
	Offset           int              `json:"offset"`
	ID               string           `json:"id"`
	Mode             string           `json:"mode"`
	Sort             string           `json:"sort"`
	HideTimeout      bool             `json:"hide_timeout"`
	Proxies          []map[string]any `json:"proxies"`
	Scripts          []string         `json:"scripts"`
	Filters          []string         `json:"filters"`
	Names            []string         `json:"names"`
	URLs             []string         `json:"urls"`
	ProxyName        string           `json:"proxy_name"`
}

type app struct {
	hostConfig        string
	dataDir           string
	runDir            string
	profile           string
	site              string
	client            *http.Client
	command           func(context.Context, string, ...string) ([]byte, error)
	runProfile        string
	coreBinary        string
	controllerAddress string
	ctx               context.Context
	jobs              sync.WaitGroup
	core              *coreRuntime
	dashboardCache    dashboardProfileCache
	probeRouteCache   probeRouteCache
}

var methods = map[string]map[string]any{
	"ip_quality":       {"url": ""},
	"probe_route":      {},
	"outbound_ip":      {"proxy_name": "", "urls": []string{}},
	"service_check":    {"proxy_name": "", "names": []string{}},
	"site_config":      {},
	"dashboard":        {},
	"settings_get":     {},
	"settings_set":     {"changes": map[string]any{}, "profile_id": ""},
	"validate_filters": {"filters": []string{}},
	"validate_scripts": {"scripts": []string{}},
	"validate_proxies": {"proxies": []map[string]any{}},
	"status":           {}, "account": {}, "sync": {}, "connect": {}, "disconnect": {}, "logout": {},
	"begin_login":    {"redirect_uri": "", "session": ""},
	"complete_login": {"code": "", "state": "", "session": ""},
	"cancel_login":   {"session": ""},
	"proxies":        {"group": "", "query": "", "offset": 0, "sort": "", "hide_timeout": false},
	"select_proxy":   {"group": "", "name": "", "close_connections": false},
	"delay_proxy":    {"name": "", "url": ""},
	"telemetry":      {}, "connections": {"query": "", "offset": 0}, "logs": {},
	"close_connection": {"id": ""}, "set_mode": {"mode": ""},
}

func newApp() (*app, error) {
	a := &app{
		dataDir: "/etc/iping", runDir: "/var/run/iping", profile: "/etc/iping/profile.yaml",
		site:              "https://iping.my",
		runProfile:        "/var/run/iping/config.yaml",
		coreBinary:        mihomoBinary,
		controllerAddress: "127.0.0.1:19090",
		ctx:               context.Background(),
		client: &http.Client{Timeout: 12 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		}},
		command: func(ctx context.Context, name string, args ...string) ([]byte, error) {
			return exec.CommandContext(ctx, name, args...).Output()
		},
	}
	for _, dir := range []string{a.dataDir, a.runDir} {
		if os.MkdirAll(dir, 0700) != nil || os.Chmod(dir, 0700) != nil {
			return nil, failure("storage_error")
		}
	}
	if _, err := os.Stat("/etc/openwrt_release"); os.IsNotExist(err) {
		a.hostConfig = filepath.Join(a.dataDir, "agent.json")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if configured, err := a.configValue(ctx, "site"); err == nil {
		u, err := url.Parse(configured)
		if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil ||
			(u.Path != "" && u.Path != "/") || u.RawQuery != "" || u.Fragment != "" {
			return nil, failure("invalid_site")
		}
		a.site = strings.TrimSuffix(u.String(), "/")
	} else if a.hostConfig != "" && !os.IsNotExist(err) {
		return nil, failure("storage_error")
	}
	return a, nil
}

func main() {
	if len(os.Args) >= 2 && os.Args[1] == "config" {
		if err := configurationCLI(os.Args[2:]); err != nil {
			os.Stderr.WriteString(err.Error() + "\n")
			os.Exit(1)
		}
		return
	}
	if len(os.Args) == 2 && os.Args[1] == "list" {
		json.NewEncoder(os.Stdout).Encode(methods)
		return
	}
	if len(os.Args) == 2 && os.Args[1] == "agent" {
		if err := serveAgent(); err != nil {
			os.Stderr.WriteString(err.Error() + "\n")
			os.Exit(1)
		}
		return
	}
	if len(os.Args) != 3 || os.Args[1] != "call" {
		os.Exit(2)
	}
	if _, exists := methods[os.Args[2]]; !exists {
		reply(nil, failure("invalid_request"))
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 18*time.Second)
	defer cancel()
	if err := forwardAgent(ctx, agentSocket, os.Args[2], os.Stdin, os.Stdout); err != nil {
		reply(nil, err)
	}
}

func reply(result any, err error) { json.NewEncoder(os.Stdout).Encode(envelope(result, err)) }

func (a *app) call(ctx context.Context, method string, args arguments) (any, error) {
	if a.ctx.Err() != nil {
		return nil, failure("interrupted")
	}
	if _, exists := methods[method]; !exists {
		return nil, failure("invalid_request")
	}
	if method == "site_config" {
		return a.siteConfig(ctx)
	}
	if method == "status" {
		return a.status(ctx)
	}
	if method == "account" {
		return a.userInfo(ctx)
	}
	switch method {
	case "ip_quality":
		return a.ipQuality(ctx, args.URL)
	case "probe_route":
		return a.probeRoute(ctx)
	case "outbound_ip":
		return a.outboundIP(ctx, args)
	case "service_check":
		return a.serviceCheck(ctx, args)
	case "dashboard":
		return a.dashboard(ctx)
	case "settings_get":
		return a.settings(ctx)
	case "validate_scripts":
		return validateResourceScripts(args.Scripts)
	case "validate_filters":
		return validateResourceFilters(args.Filters)
	case "validate_proxies":
		return a.validateResourceProxies(ctx, args.Proxies)
	case "proxies":
		return a.proxies(ctx, args)
	case "telemetry":
		return a.telemetry(ctx)
	case "connections":
		return a.connections(ctx, args)
	case "logs":
		return a.logs()
	case "delay_proxy":
		return a.delayProxy(ctx, args.Name, args.URL)
	}
	lock, err := a.lock()
	if err != nil {
		return nil, err
	}
	defer lock.Close()
	switch method {
	case "settings_set":
		if args.ProfileID != "" {
			id, err := a.resourceProfileID()
			if err != nil {
				return nil, err
			}
			if id != args.ProfileID {
				return nil, failure("resource_changed")
			}
		}
		return a.queueSettings(ctx, args.Changes, lock)
	case "begin_login":
		return a.beginLogin(args)
	case "complete_login":
		return a.completeLogin(ctx, args)
	case "cancel_login":
		return a.cancelLogin(args)
	case "select_proxy":
		return nil, a.selectProxy(ctx, args)
	case "set_mode":
		return nil, a.setMode(ctx, args.Mode)
	case "close_connection":
		if args.ID != "" && !accessKey.MatchString(args.ID) {
			return nil, failure("invalid_request")
		}
		_, err := a.controller(ctx, http.MethodDelete, "/connections/"+url.PathEscape(args.ID), nil)
		return nil, err
	default:
		return a.startJob(method, lock)
	}
}

func (a *app) startJob(action string, lock *os.File) (any, error) {
	if a.ctx.Err() != nil || a.core.closed.Load() {
		return nil, failure("interrupted")
	}
	if action == "sync" || action == "connect" {
		if _, err := a.account(); err != nil {
			return nil, err
		}
	}
	job := jobInfo{Action: action, Started: time.Now().Unix()}
	if err := writeJSON(filepath.Join(a.runDir, "job.json"), job); err != nil {
		return nil, failure("storage_error")
	}
	syscall.ForkLock.RLock()
	duplicate, err := syscall.Dup(int(lock.Fd()))
	if err == nil {
		syscall.CloseOnExec(duplicate)
	}
	syscall.ForkLock.RUnlock()
	if err != nil {
		return nil, failure("service_failed")
	}
	owned := os.NewFile(uintptr(duplicate), "iping-job")
	a.jobs.Add(1)
	go func() {
		defer a.jobs.Done()
		defer owned.Close()
		ctx, cancel := context.WithTimeout(a.ctx, 100*time.Second)
		defer cancel()
		a.runJob(ctx, action)
	}()

	return nil, nil
}

func (a *app) runJob(ctx context.Context, action string) {
	var job jobInfo
	readJSON(filepath.Join(a.runDir, "job.json"), &job)
	var err error
	switch action {
	case "apply_settings":
		err = a.applySettings(ctx)
	case "sync":
		err = a.syncProfile(ctx)
	case "connect":
		err = a.connect(ctx)
	case "disconnect":
		err = a.disconnect(ctx)
	case "logout":
		err = a.logout(ctx)
	default:
		err = failure("invalid_request")
	}
	job.Done = true
	if err != nil {
		var public failure
		if !errors.As(err, &public) {
			public = failure("storage_error")
		}
		job.Error = public.Error()
	}
	writeJSON(filepath.Join(a.runDir, "job.json"), job)
}

func (a *app) status(ctx context.Context) (any, error) {
	lock, err := a.lock()
	busy := err != nil
	if lock != nil {
		lock.Close()
	}
	var job jobInfo
	readJSON(filepath.Join(a.runDir, "job.json"), &job)
	if !busy && job.Action != "" && !job.Done {
		job.Done, job.Error = true, "interrupted"
	}
	account, accountErr := a.account()
	var profile profileInfo
	readJSON(filepath.Join(a.dataDir, "profile.json"), &profile)
	return map[string]any{
		"logged_in": accountErr == nil, "email": account.Email, "site": a.site,
		"nodes": profile.Nodes, "synced": profile.Synced, "busy": busy || a.core.working.Load() > 0, "job": job,
		"running": a.running(ctx),
	}, nil
}

func configurationCLI(args []string) error {
	if len(args) < 2 || len(args) > 3 {
		return failure("invalid_request")
	}
	switch args[1] {
	case "site", "enabled", "web_listen", "auto_update", "update_url", "update_minute":
	default:
		return failure("invalid_request")
	}
	a, err := newApp()
	if err != nil {
		return err
	}
	if args[0] == "get" && len(args) == 2 {
		value, err := a.configValue(context.Background(), args[1])
		if err != nil {
			return err
		}
		_, err = os.Stdout.WriteString(value + "\n")
		return err
	}
	if args[0] == "set" && len(args) == 3 {
		return a.setConfigValue(context.Background(), args[1], args[2])
	}
	return failure("invalid_request")
}
