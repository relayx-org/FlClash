package probe

import (
	"context"
	"net/netip"
	"strings"
	"time"

	"net/http"
)

const (
	// Racing every source at once would take every probe slot.
	outboundIpConcurrency = 3
	outboundIpStagger     = 800 * time.Millisecond

	outboundIpMaxBody = 4096

	// Kept in step with browserUa in lib/common/constant.dart.
	BrowserUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

type OutboundIpParams struct {
	ProxyName string   `json:"proxy-name"`
	Urls      []string `json:"urls"`
	Timeout   int64    `json:"timeout"`
}

type OutboundIpResult struct {
	Url          string   `json:"url"`
	Body         string   `json:"body"`
	Delay        int64    `json:"delay"`
	Chains       []string `json:"chains"`
	Error        string   `json:"error,omitempty"`
	CoreEpoch    uint64   `json:"core-epoch"`
	PicksVersion uint64   `json:"picks-version"`
}

// Dart owns the source parsers; retain the requested URL even after redirects.
func (r *Runner) OutboundIP(parent context.Context, params *OutboundIpParams) *OutboundIpResult {
	epoch, picksVersion := r.stamp()
	failure := func(kind string) *OutboundIpResult {
		return &OutboundIpResult{Error: kind, CoreEpoch: epoch, PicksVersion: picksVersion}
	}
	if len(params.Urls) == 0 {
		return failure(probeErrorFailed)
	}

	timeout := timeoutFromMillis(params.Timeout, defaultProbeTimeout)
	ctx, cancel := context.WithTimeout(parent, timeout)
	defer cancel()

	answers := make(chan *OutboundIpResult, len(params.Urls))
	next := 0
	inFlight := 0
	start := func() {
		if next >= len(params.Urls) || inFlight >= outboundIpConcurrency {
			return
		}
		url := params.Urls[next]
		next++
		inFlight++
		go func() {
			answers <- r.probeOutboundIpSource(ctx, url, params.ProxyName, timeout)
		}()
	}

	start()

	stagger := time.NewTicker(outboundIpStagger)
	defer stagger.Stop()
	for inFlight > 0 {
		select {
		case answer := <-answers:
			inFlight--
			if answer != nil {
				return answer
			}
			start()
		case <-stagger.C:
			start()
		case <-ctx.Done():
			return failure(probeErrorTimeout)
		}
	}
	return failure(probeErrorFailed)
}

func (r *Runner) probeOutboundIpSource(ctx context.Context, url string, proxyName string, timeout time.Duration) *OutboundIpResult {
	result := r.Send(ctx, Request{
		Method:    http.MethodGet,
		URL:       url,
		ProxyName: proxyName,
		Headers:   map[string]string{"User-Agent": BrowserUserAgent},
		Timeout:   timeout,
		MaxBody:   outboundIpMaxBody,
	})
	if result == nil || result.Error != "" || result.StatusCode != http.StatusOK || !MentionsIP(result.Body) {
		return nil
	}
	return &OutboundIpResult{
		Url:          url,
		Body:         result.Body,
		Delay:        result.Delay,
		Chains:       result.Chains,
		CoreEpoch:    result.CoreEpoch,
		PicksVersion: result.PicksVersion,
	}
}

// RFC 6598 space for carrier-grade NAT, which IsPrivate leaves out.
var sharedAddressSpace = netip.MustParsePrefix("100.64.0.0/10")

// A rate-limit or captcha page can still answer 200, and Dart cannot fall back
// once the race is decided, so a body without a public address must not win it.
func MentionsIP(body string) bool {
	tokens := strings.FieldsFunc(body, func(r rune) bool {
		return !(r == '.' || r == ':' || '0' <= r && r <= '9' || 'a' <= r && r <= 'z' || 'A' <= r && r <= 'Z')
	})
	for _, token := range tokens {
		addr, err := netip.ParseAddr(token)
		if err != nil {
			continue
		}
		addr = addr.Unmap()
		if addr.IsGlobalUnicast() && !addr.IsPrivate() && !sharedAddressSpace.Contains(addr) {
			return true
		}
	}
	return false
}
