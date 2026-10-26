package main

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestWebDiagnosticsAreBoundedAndOnlyAvailableLocally(t *testing.T) {
	handler := (&app{}).webHandler()
	request := func(method, origin, client, body string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, "http://router/api/web_diagnostics", strings.NewReader(body))
		r.RemoteAddr = client
		r.Header.Set("Origin", origin)
		r.Header.Set("User-Agent", strings.Repeat("x", 600))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	for _, input := range []struct {
		method, origin, client, body string
		status                       int
	}{
		{"POST", "http://other", "192.168.1.2:1234", `{}`, 403},
		{"POST", "http://router", "203.0.113.1:1234", `{}`, 403},
		{"GET", "http://router", "192.168.1.2:1234", `{}`, 405},
		{"POST", "http://router", "192.168.1.2:1234", `{"report":null}`, 400},
		{"POST", "http://router", "192.168.1.2:1234", `{"report":[]}`, 400},
		{"POST", "http://router", "192.168.1.2:1234", `{} {}`, 400},
		{"POST", "http://router", "192.168.1.2:1234", `{"unknown":1}`, 400},
		{"POST", "http://router", "192.168.1.2:1234", `{"report":{"large":"` + strings.Repeat("x", 16384) + `"}}`, 400},
	} {
		if w := request(input.method, input.origin, input.client, input.body); w.Code != input.status {
			t.Fatalf("request %s %s: status %d, expected %d", input.method, input.origin, w.Code, input.status)
		}
	}
	for i := range 30 {
		w := request("POST", "http://router", "192.168.1.2:1234", fmt.Sprintf(`{"report":{"sequence":%d}}`, i))
		if w.Code != 200 || len(w.Result().Cookies()) != 0 {
			t.Fatalf("sample %d: %d %s", i, w.Code, w.Body.String())
		}
	}
	w := request("POST", "http://router", "192.168.1.2:1234", `{}`)
	var response struct {
		OK   bool                  `json:"ok"`
		Data []webDiagnosticSample `json:"data"`
	}
	if json.Unmarshal(w.Body.Bytes(), &response) != nil || !response.OK || len(response.Data) != 24 || w.Header().Get("Cache-Control") != "no-store" {
		t.Fatalf("stored diagnostics: %d %s", w.Code, w.Body.String())
	}
	for i, sample := range response.Data {
		if sample.Received.IsZero() || len(sample.UserAgent) != 512 || string(sample.Report) != fmt.Sprintf(`{"sequence":%d}`, i+6) {
			t.Fatalf("unexpected retained sample %d: %+v", i, sample)
		}
	}
}
