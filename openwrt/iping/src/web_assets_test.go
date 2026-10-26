package main

import (
	"bytes"
	"compress/gzip"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"
)

func TestWebAssets(t *testing.T) {
	var compressed bytes.Buffer
	encoder := gzip.NewWriter(&compressed)
	_, _ = encoder.Write([]byte("compressed-only asset"))
	_ = encoder.Close()
	files := fstest.MapFS{
		"index.html":                           {Data: []byte("<html>iPing</html>")},
		"main.dart.js":                         {Data: []byte("uncompressed javascript")},
		"main.dart.js.gz":                      {Data: []byte("compressed javascript")},
		"canvaskit/engine.wasm":                {Data: []byte("wasm")},
		"assets/font.ttf":                      {Data: []byte("font")},
		"fallback-fonts/notosanssc/font.woff2": {Data: []byte("local Chinese font")},
		"packed.js.gz":                         {Data: compressed.Bytes()},
		"ui-version":                           {Data: []byte("ui1")},
		"renderer-version":                     {Data: []byte("engine1")},
		"asset-etags.json":                     {Data: []byte(`{"main.dart.js":"plain","main.dart.js.gz":"gzip"}`)},
	}
	handler := webAssets(files)
	request := func(method, target, encoding, etag, byteRange string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, target, nil)
		r.Header.Set("Accept-Encoding", encoding)
		r.Header.Set("If-None-Match", etag)
		r.Header.Set("Range", byteRange)
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	for _, encoding := range []string{"gzip", "br, gzip;q=0.5", "*"} {
		w := request("GET", "/main.dart.js?v=ui1", encoding, "", "")
		if w.Code != 200 || w.Header().Get("Content-Encoding") != "gzip" || w.Body.String() != "compressed javascript" {
			t.Fatalf("gzip response for %q: %d %v %s", encoding, w.Code, w.Header(), w.Body.String())
		}
		if !strings.Contains(w.Header().Get("Content-Type"), "javascript") || w.Header().Get("ETag") != `"gzip"` || !strings.Contains(w.Header().Get("Cache-Control"), "immutable") {
			t.Fatalf("gzip metadata: %v", w.Header())
		}
	}
	for _, encoding := range []string{"", "br", "gzip;q=0, *;q=1", "gzip;q=bad"} {
		w := request("GET", "/main.dart.js", encoding, "", "")
		if w.Code != 200 || w.Header().Get("Content-Encoding") != "" || w.Body.String() != "uncompressed javascript" || w.Header().Get("Cache-Control") != "no-cache" {
			t.Fatalf("identity response for %q: %d %v", encoding, w.Code, w.Header())
		}
	}
	w := request("GET", "/main.dart.js", "gzip", `"gzip"`, "")
	if w.Code != http.StatusNotModified || w.Body.Len() != 0 {
		t.Fatalf("conditional response: %d %s", w.Code, w.Body.String())
	}
	w = request("HEAD", "/main.dart.js", "gzip", "", "")
	if w.Code != 200 || w.Body.Len() != 0 || w.Header().Get("Content-Length") != "21" {
		t.Fatalf("head response: %d %v", w.Code, w.Header())
	}
	w = request("GET", "/main.dart.js", "gzip", "", "bytes=0-3")
	if w.Code != 206 || w.Header().Get("Content-Encoding") != "" || w.Body.String() != "unco" {
		t.Fatalf("range response: %d %s", w.Code, w.Body.String())
	}
	for _, target := range []string{"/ui/ui1/assets/font.ttf", "/canvaskit/engine1/engine.wasm"} {
		w = request("GET", target, "gzip", "", "")
		if w.Code != 200 || !strings.Contains(w.Header().Get("Cache-Control"), "immutable") {
			t.Fatalf("versioned asset %s: %d %v", target, w.Code, w.Header())
		}
	}
	for _, target := range []string{"/ui/old/assets/font.ttf", "/main.dart.js.gz", "/assets/", "/asset-etags.json"} {
		if w = request("GET", target, "", "", ""); w.Code != 404 {
			t.Fatalf("unexpected public asset %s: %d", target, w.Code)
		}
	}
	if w = request("GET", "/", "", "", ""); w.Code != 200 || w.Header().Get("Cache-Control") != "no-cache" {
		t.Fatalf("entrypoint cache: %d %v", w.Code, w.Header())
	}
	w = request("GET", "/ui/ui1/fallback-fonts/notosanssc/font.woff2", "", "", "")
	if w.Code != 200 || w.Body.String() != "local Chinese font" || w.Header().Get("Content-Type") != "font/woff2" {
		t.Fatalf("local fallback font: %d %v", w.Code, w.Header())
	}
	w = request("GET", "/ui/ui1/fallback-fonts/notosanskr/font.woff2", "", "", "")
	if w.Code != 302 || w.Header().Get("Location") != "https://fonts.gstatic.com/s/notosanskr/font.woff2" {
		t.Fatalf("other fallback family: %d %v", w.Code, w.Header())
	}
	for _, byteRange := range []string{"", "bytes=0-3"} {
		w = request("GET", "/packed.js", "", "", byteRange)
		if w.Header().Get("Content-Encoding") != "" || !strings.HasPrefix("compressed-only asset", w.Body.String()) || w.Body.Len() == 0 {
			t.Fatalf("compressed-only fallback: %d %v %s", w.Code, w.Header(), w.Body.String())
		}
	}
}
