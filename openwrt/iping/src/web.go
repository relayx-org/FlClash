package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"io"
	"mime"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/relayx-org/FlClash/openwrt/iping/webui"
)

func browserSession(w http.ResponseWriter, r *http.Request) (string, error) {
	name := "iping_session"
	if r.TLS != nil {
		name = "iping_secure_session"
	}
	if cookie, err := r.Cookie(name); err == nil && sessionID.MatchString(cookie.Value) && strings.Trim(cookie.Value, "0") != "" {
		return cookie.Value, nil
	}
	var random [16]byte
	if _, err := rand.Read(random[:]); err != nil {
		return "", err
	}
	id := hex.EncodeToString(random[:])
	http.SetCookie(w, &http.Cookie{Name: name, Value: id, Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode, Secure: r.TLS != nil, MaxAge: 12 * 60 * 60})
	return id, nil
}

func sameOrigin(r *http.Request) bool {
	origin, err := url.Parse(r.Header.Get("Origin"))
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return err == nil && origin.Scheme == scheme && origin.Host == r.Host && origin.Path == "" && origin.User == nil
}

func privateClient(r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return false
	}
	ip := net.ParseIP(host)
	return ip != nil && (ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast())
}

func webReply(w http.ResponseWriter, status int, data any, err error) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(envelope(data, err))
}

func (a *app) webHandler() http.Handler {
	mime.AddExtensionType(".wasm", "application/wasm")
	files := webAssets(webui.Files())
	diagnostics := &webDiagnostics{}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.TLS != nil {
			w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
			w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
		}
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		if !privateClient(r) {
			webReply(w, 403, nil, failure("invalid_request"))
			return
		}
		if strings.HasPrefix(r.URL.Path, "/api/") {
			if !sameOrigin(r) {
				webReply(w, 403, nil, failure("invalid_request"))
				return
			}
			if r.Method != http.MethodPost {
				webReply(w, 405, nil, failure("invalid_request"))
				return
			}
			if r.URL.Path == "/api/web_diagnostics" {
				diagnostics.serveHTTP(w, r)
				return
			}
			method := strings.TrimPrefix(r.URL.Path, "/api/")
			if _, exists := methods[method]; !exists {
				webReply(w, 404, nil, failure("invalid_request"))
				return
			}
			var args arguments
			decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 512*1024))
			if decoder.Decode(&args) != nil || decoder.Decode(&struct{}{}) != io.EOF {
				webReply(w, 400, nil, failure("invalid_request"))
				return
			}
			id, err := browserSession(w, r)
			if err != nil {
				webReply(w, 500, nil, err)
				return
			}
			args.Session = id
			result, err := a.call(r.Context(), method, args)
			webReply(w, 200, result, err)
			return
		}
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.WriteHeader(405)
			return
		}
		if r.URL.Path == "/" || r.URL.Path == "/index.html" {
			w.Header().Set("Cache-Control", "no-cache")
		}
		files.ServeHTTP(w, r)
	})
}

func (a *app) webAddress(ctx context.Context) (string, error) {
	return a.webListenAddress(ctx, "web_listen", "0.0.0.0:19091", 1024)
}

func (a *app) webListenAddress(ctx context.Context, setting, address string, minimum int) (string, error) {
	if value, err := a.command(ctx, "/sbin/uci", "-q", "get", "iping.config."+setting); err == nil {
		address = strings.TrimSpace(string(value))
	}
	if address == "" && setting == "web_tls_listen" {
		return "", nil
	}
	host, port, err := net.SplitHostPort(address)
	number, parseErr := strconv.Atoi(port)
	if err != nil || parseErr != nil || number < minimum || number > 65535 || net.ParseIP(host) == nil {
		return "", failure("invalid_request")
	}
	return address, nil
}
