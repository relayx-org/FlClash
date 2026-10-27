package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"hash/fnv"
	"net"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/relayx-org/FlClash/openwrt/iping/probe"
	"go.yaml.in/yaml/v3"
)

type probeRouteCache struct {
	mu          sync.Mutex
	fingerprint string
	version     uint64
}

type probeRoute struct {
	Epoch   uint64            `json:"core-epoch"`
	Version uint64            `json:"picks-version"`
	Picks   map[string]string `json:"picks"`
	Proxied bool              `json:"proxied"`
}

func (a *app) probeRoute(ctx context.Context) (*probeRoute, error) {
	if _, err := a.subscriptionURL(); err != nil {
		return nil, err
	}
	cache := &a.probeRouteCache
	cache.mu.Lock()
	defer cache.mu.Unlock()
	route := &probeRoute{Picks: map[string]string{}, Proxied: a.running(ctx)}
	mode := "direct"
	if route.Proxied {
		child := a.core.current.Load()
		if child == nil {
			return nil, failure("controller_unavailable")
		}
		route.Epoch = uint64(child.started.UnixMilli())
		var err error
		mode, err = a.coreMode(ctx)
		if err != nil {
			return nil, err
		}
		proxies, err := a.proxyMap(ctx)
		if err != nil {
			return nil, err
		}
		for name, proxy := range proxies {
			if len(proxy.All) > 0 {
				route.Picks[name] = proxy.Now
			}
		}
	}
	names := make([]string, 0, len(route.Picks))
	for name := range route.Picks {
		names = append(names, name)
	}
	sort.Strings(names)
	hash := fnv.New64a()
	fmt.Fprintf(hash, "%d\x00%s\x00", route.Epoch, mode)
	for _, name := range names {
		fmt.Fprintf(hash, "%s\x00%s\x00", name, route.Picks[name])
	}
	fingerprint := strconv.FormatUint(hash.Sum64(), 16)
	if cache.fingerprint != fingerprint {
		cache.version++
		cache.fingerprint = fingerprint
	}
	route.Version = cache.version
	return route, nil
}

func (a *app) probeProxy(ctx context.Context, direct bool) (*url.URL, error) {
	if direct {
		return nil, nil
	}
	data, err := os.ReadFile(a.runProfile)
	var config struct {
		Mixed          int      `yaml:"mixed-port"`
		HTTP           int      `yaml:"port"`
		SOCKS          int      `yaml:"socks-port"`
		Authentication []string `yaml:"authentication"`
	}
	if err != nil || yaml.Unmarshal(data, &config) != nil {
		return nil, failure("controller_unavailable")
	}
	port, scheme := config.Mixed, "http"
	if port == 0 {
		port = config.HTTP
	}
	if port == 0 {
		port, scheme = config.SOCKS, "socks5"
	}
	if port < 1 || port > 65535 {
		return nil, failure("controller_unavailable")
	}
	proxy := &url.URL{Scheme: scheme, Host: net.JoinHostPort("127.0.0.1", strconv.Itoa(port))}
	if len(config.Authentication) > 0 {
		user, password, ok := strings.Cut(config.Authentication[0], ":")
		if !ok {
			return nil, failure("controller_unavailable")
		}
		proxy.User = url.UserPassword(user, password)
	}
	return proxy, nil
}

var probeSlots = make(chan struct{}, 8)

func (a *app) probeRunner(ctx context.Context, proxyName string) (*probe.Runner, *probeRoute, func(), error) {
	if proxyName != "" && proxyName != "DIRECT" {
		return nil, nil, nil, failure("invalid_request")
	}
	route, err := a.probeRoute(ctx)
	if err != nil {
		return nil, nil, nil, err
	}
	proxy, err := a.probeProxy(ctx, proxyName == "DIRECT" || !route.Proxied)
	if err != nil {
		return nil, nil, nil, err
	}
	transport := &http.Transport{DialContext: (&net.Dialer{Timeout: 4 * time.Second}).DialContext, TLSHandshakeTimeout: 4 * time.Second, MaxIdleConns: 8, IdleConnTimeout: 10 * time.Second}
	if proxy != nil {
		transport.Proxy = http.ProxyURL(proxy)
	}
	runner := &probe.Runner{Stamp: func() (uint64, uint64) { return route.Epoch, route.Version }}
	runner.Send = func(parent context.Context, req probe.Request) *probe.Result {
		result := &probe.Result{Url: req.URL, Chains: []string{}}
		result.CoreEpoch, result.PicksVersion = route.Epoch, route.Version
		fail := func(err error) *probe.Result {
			result.Error = "failed"
			var netErr net.Error
			if errors.Is(err, context.DeadlineExceeded) || errors.As(err, &netErr) && netErr.Timeout() {
				result.Error = "timeout"
			}
			return result
		}
		timeout := req.Timeout
		if timeout <= 0 || timeout > 4*time.Second {
			timeout = 4 * time.Second
		}
		queue, cancelQueue := context.WithTimeout(parent, timeout)
		defer cancelQueue()
		select {
		case probeSlots <- struct{}{}:
		case <-queue.Done():
			return fail(queue.Err())
		}
		defer func() { <-probeSlots }()
		requestCtx, cancel := context.WithTimeout(parent, timeout)
		defer cancel()
		request, err := http.NewRequestWithContext(requestCtx, req.Method, req.URL, bytes.NewReader(req.Body))
		if err != nil {
			return fail(err)
		}
		for name, value := range req.Headers {
			request.Header.Set(name, value)
		}
		client := &http.Client{Transport: transport}
		if req.NoRedirect {
			client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
		}
		started := time.Now()
		response, err := client.Do(request)
		if err != nil {
			return fail(err)
		}
		defer response.Body.Close()
		result.Delay = time.Since(started).Milliseconds()
		result.StatusCode, result.Header = response.StatusCode, response.Header
		result.Url = response.Request.URL.String()
		if req.MaxBody > 0 {
			result.Body = probe.ReadBody(response.Body, req.MaxBody, req.Until)
		}
		return result
	}
	return runner, route, transport.CloseIdleConnections, nil
}

func (a *app) probeContext(parent context.Context) (context.Context, func()) {
	ctx, cancel := context.WithTimeout(parent, 15*time.Second)
	stop := context.AfterFunc(a.ctx, cancel)
	return ctx, func() { stop(); cancel() }
}

func (a *app) outboundIP(parent context.Context, args arguments) (any, error) {
	if len(args.URLs) == 0 || len(args.URLs) > 12 {
		return nil, failure("invalid_request")
	}
	for _, raw := range args.URLs {
		u, err := url.Parse(raw)
		if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Hostname() == "" || u.User != nil {
			return nil, failure("invalid_request")
		}
	}
	ctx, cancel := a.probeContext(parent)
	defer cancel()
	runner, _, close, err := a.probeRunner(ctx, args.ProxyName)
	if err != nil {
		return nil, err
	}
	defer close()
	result := runner.OutboundIP(ctx, &probe.OutboundIpParams{ProxyName: args.ProxyName, Urls: args.URLs, Timeout: 6000})
	return result, nil
}

func (a *app) serviceCheck(parent context.Context, args arguments) (any, error) {
	if len(args.Names) != 1 {
		return nil, failure("invalid_request")
	}
	ctx, cancel := a.probeContext(parent)
	defer cancel()
	runner, _, close, err := a.probeRunner(ctx, args.ProxyName)
	if err != nil {
		return nil, err
	}
	defer close()
	return runner.CheckServices(ctx, &probe.ServiceCheckParams{ProxyName: args.ProxyName, Names: args.Names, Timeout: 4000}), nil
}

func (a *app) ipQuality(parent context.Context, raw string) (any, error) {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.User != nil || u.Port() != "" {
		return nil, failure("invalid_request")
	}
	switch u.Hostname() {
	case "ident.me", "ip-api.com", "api.ipquery.io", "iplocate.io", "proxycheck.io", "api.ipapi.is":
	default:
		return nil, failure("invalid_request")
	}
	ctx, cancel := a.probeContext(parent)
	defer cancel()
	runner, _, close, err := a.probeRunner(ctx, "")
	if err != nil {
		return nil, err
	}
	defer close()
	result := runner.Send(ctx, probe.Request{Method: http.MethodGet, URL: raw, Timeout: 4 * time.Second, MaxBody: 64 * 1024})
	if result == nil {
		return nil, failure("network_error")
	}
	return map[string]any{"status": result.StatusCode, "body": result.Body, "error": result.Error}, nil
}
