package probe

import (
	"context"
	"net/http"
	"time"
)

const (
	defaultProbeTimeout = 10 * time.Second
	probeErrorTimeout   = "timeout"
	probeErrorFailed    = "failed"
)

type Request struct {
	Method     string
	URL        string
	ProxyName  string
	Headers    map[string]string
	Body       []byte
	Timeout    time.Duration
	MaxBody    int64
	NoRedirect bool
	Until      func(string) bool
}

type Result struct {
	StatusCode   int
	Delay        int64
	Body         string
	Url          string
	Chains       []string
	Error        string
	Header       http.Header
	CoreEpoch    uint64
	PicksVersion uint64
	lowerBody    string
}

type Runner struct {
	Send  func(context.Context, Request) *Result
	Stamp func() (uint64, uint64)
}

func (r *Runner) stamp() (uint64, uint64) {
	if r.Stamp == nil {
		return 0, 0
	}
	return r.Stamp()
}
