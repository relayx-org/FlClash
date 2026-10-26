package core

import (
	"context"
	probe "github.com/relayx-org/FlClash/openwrt/iping/probe"
	"net/http"
)

var coreProbes = &probe.Runner{Stamp: routeStamp, Send: func(ctx context.Context, req probe.Request) *probe.Result {
	result := runProbe(ctx, probeRequest{
		method: req.Method, url: req.URL, proxyName: req.ProxyName,
		headers: req.Headers, body: req.Body, timeout: req.Timeout,
		maxBody: req.MaxBody, noRedirect: req.NoRedirect, until: req.Until,
	})
	if result == nil {
		return nil
	}
	return &probe.Result{
		StatusCode: result.StatusCode, Delay: result.Delay, Body: result.Body, Url: result.Url,
		Chains: result.Chains, Error: result.Error, Header: http.Header(result.header),
		CoreEpoch: result.CoreEpoch, PicksVersion: result.PicksVersion,
	}
}}
