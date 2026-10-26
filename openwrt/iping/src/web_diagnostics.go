package main

import (
	"encoding/json"
	"io"
	"net/http"
	"sync"
	"time"
)

type webDiagnosticSample struct {
	Received  time.Time       `json:"received"`
	UserAgent string          `json:"user_agent"`
	Report    json.RawMessage `json:"report"`
}

type webDiagnostics struct {
	mu      sync.Mutex
	samples []webDiagnosticSample
}

func (d *webDiagnostics) serveHTTP(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Report json.RawMessage `json:"report"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16*1024))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&request) != nil || decoder.Decode(&struct{}{}) != io.EOF {
		webReply(w, 400, nil, failure("invalid_request"))
		return
	}
	if len(request.Report) > 0 {
		var object map[string]json.RawMessage
		if json.Unmarshal(request.Report, &object) != nil || object == nil {
			webReply(w, 400, nil, failure("invalid_request"))
			return
		}
		userAgent := r.UserAgent()
		if len(userAgent) > 512 {
			userAgent = userAgent[:512]
		}
		d.mu.Lock()
		d.samples = append(d.samples, webDiagnosticSample{
			Received: time.Now().UTC(), UserAgent: userAgent, Report: request.Report,
		})
		if len(d.samples) > 24 {
			d.samples = append([]webDiagnosticSample(nil), d.samples[len(d.samples)-24:]...)
		}
		d.mu.Unlock()
		webReply(w, 200, nil, nil)
		return
	}
	d.mu.Lock()
	samples := append([]webDiagnosticSample{}, d.samples...)
	d.mu.Unlock()
	webReply(w, 200, samples, nil)
}
