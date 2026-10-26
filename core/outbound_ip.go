package core

import (
	"context"
	probe "github.com/relayx-org/FlClash/openwrt/iping/probe"
)

const browserUserAgent = probe.BrowserUserAgent

type OutboundIpParams = probe.OutboundIpParams
type OutboundIpResult = probe.OutboundIpResult

func handleOutboundIp(params *OutboundIpParams) *OutboundIpResult {
	return coreProbes.OutboundIP(context.Background(), params)
}
