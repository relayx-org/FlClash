package main

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"io"
	"mime"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/relayx-org/FlClash/openwrt/iping/webui"
)

const ownerCookie = "iping_owner"

func (a *app) accessKey() (string, error) {
	path := filepath.Join(a.dataDir, "web-key")
	data, err := os.ReadFile(path)
	if err == nil {
		if len(data) != 64 {
			return "", failure("storage_error")
		}
		return string(data), nil
	}
	if !os.IsNotExist(err) {
		return "", failure("storage_error")
	}
	var raw [32]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return "", err
	}
	key := hex.EncodeToString(raw[:])
	if err := writePrivate(path, []byte(key)); err != nil {
		return "", err
	}
	return key, nil
}

func signSession(key, value string) string {
	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(value))
	return hex.EncodeToString(mac.Sum(nil))
}

func ownerSession(r *http.Request, key string) string {
	cookie, err := r.Cookie(ownerCookie)
	if err != nil {
		return ""
	}
	parts := strings.Split(cookie.Value, ".")
	if len(parts) != 3 || !sessionID.MatchString(parts[0]) {
		return ""
	}
	expiry, err := strconv.ParseInt(parts[1], 10, 64)
	if err != nil || expiry <= time.Now().Unix() {
		return ""
	}
	expected := signSession(key, parts[0]+"."+parts[1])
	if subtle.ConstantTimeCompare([]byte(expected), []byte(parts[2])) != 1 {
		return ""
	}
	return parts[0]
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

func (a *app) webHandler(key string) http.Handler {
	mime.AddExtensionType(".wasm", "application/wasm")
	files := http.FileServer(http.FS(webui.Files()))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		if !privateClient(r) {
			webReply(w, 403, nil, failure("access_required"))
			return
		}
		if r.URL.Path == "/api/session" {
			if r.Method == http.MethodGet {
				webReply(w, 200, map[string]any{"authenticated": ownerSession(r, key) != ""}, nil)
				return
			}
			if r.Method != http.MethodPost || !sameOrigin(r) {
				webReply(w, 403, nil, failure("access_required"))
				return
			}
			var input struct {
				Key string `json:"key"`
			}
			decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096))
			if decoder.Decode(&input) != nil || decoder.Decode(&struct{}{}) != io.EOF || subtle.ConstantTimeCompare([]byte(key), []byte(input.Key)) != 1 {
				webReply(w, 401, nil, failure("access_invalid"))
				return
			}
			var random [16]byte
			if _, err := rand.Read(random[:]); err != nil {
				webReply(w, 500, nil, err)
				return
			}
			id := hex.EncodeToString(random[:])
			value := id + "." + strconv.FormatInt(time.Now().Add(12*time.Hour).Unix(), 10)
			http.SetCookie(w, &http.Cookie{Name: ownerCookie, Value: value + "." + signSession(key, value), Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode, Secure: r.TLS != nil, MaxAge: 12 * 60 * 60})
			webReply(w, 200, map[string]any{"authenticated": true}, nil)
			return
		}
		if strings.HasPrefix(r.URL.Path, "/api/") {
			id := ownerSession(r, key)
			if id == "" || !sameOrigin(r) {
				webReply(w, 401, nil, failure("access_required"))
				return
			}
			if r.Method != http.MethodPost {
				webReply(w, 405, nil, failure("invalid_request"))
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
	address := "0.0.0.0:19091"
	if value, err := a.command(ctx, "/sbin/uci", "-q", "get", "iping.config.web_listen"); err == nil {
		address = strings.TrimSpace(string(value))
	}
	host, port, err := net.SplitHostPort(address)
	number, parseErr := strconv.Atoi(port)
	if err != nil || parseErr != nil || number < 1024 || number > 65535 || net.ParseIP(host) == nil {
		return "", failure("invalid_request")
	}
	return address, nil
}
