package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var (
	loginParameter = regexp.MustCompile(`^[A-Za-z0-9_-]{43}$`)
	sessionID      = regexp.MustCompile(`^[0-9a-f]{32}$`)
	accessKey      = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
)

type pendingLogin struct {
	State    string `json:"state"`
	Verifier string `json:"verifier"`
	Session  string `json:"session"`
	Expires  int64  `json:"expires"`
}

func digest(value string) string {
	hash := sha256.Sum256([]byte(value))
	return base64.RawURLEncoding.EncodeToString(hash[:])
}

func randomParameter() (string, error) {
	var data [32]byte
	if _, err := rand.Read(data[:]); err != nil {
		return "", failure("storage_error")
	}
	return base64.RawURLEncoding.EncodeToString(data[:]), nil
}

func validCallback(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.User != nil ||
		u.Path != "/iping-login.html" || u.RawQuery != "" || u.Fragment != "" || u.RawPath != "" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	if ip := net.ParseIP(host); ip != nil {
		if strings.Contains(host, ":") && ip.To4() != nil {
			return false
		}
		return ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast()
	}
	return host == "localhost" || host == "openwrt" || strings.HasSuffix(host, ".lan") || strings.HasSuffix(host, ".local")
}

func validCredentials(account credentials) bool {
	return account.ID > 0 && account.Email != "" && len(account.Email) <= 320 &&
		account.SubscriptionToken != "" && len(account.SubscriptionToken) <= 4096 && accessKey.MatchString(account.AccessKey)
}

func (a *app) beginLogin(args arguments) (any, error) {
	if !sessionID.MatchString(args.Session) || strings.Trim(args.Session, "0") == "" || !validCallback(args.RedirectURI) {
		return nil, failure("invalid_login")
	}
	if _, err := a.account(); err == nil {
		return nil, failure("already_logged_in")
	}
	state, err := randomParameter()
	if err != nil {
		return nil, err
	}
	verifier, err := randomParameter()
	if err != nil {
		return nil, err
	}
	pending := pendingLogin{state, verifier, digest(args.Session), time.Now().Add(5 * time.Minute).Unix()}
	if err := writeJSON(filepath.Join(a.runDir, "login.json"), pending); err != nil {
		return nil, failure("storage_error")
	}
	query := url.Values{
		"state": {state}, "code_challenge": {digest(verifier)},
		"code_challenge_method": {"S256"}, "redirect_uri": {args.RedirectURI},
	}
	return map[string]any{"url": a.site + "/client-login?" + query.Encode(), "state": state}, nil
}

func (a *app) completeLogin(ctx context.Context, args arguments) (any, error) {
	var pending pendingLogin
	path := filepath.Join(a.runDir, "login.json")
	if !sessionID.MatchString(args.Session) || !loginParameter.MatchString(args.Code) ||
		!loginParameter.MatchString(args.State) || readJSON(path, &pending) != nil ||
		pending.Expires < time.Now().Unix() ||
		subtle.ConstantTimeCompare([]byte(pending.State), []byte(args.State)) != 1 ||
		subtle.ConstantTimeCompare([]byte(pending.Session), []byte(digest(args.Session))) != 1 {
		return nil, failure("login_expired")
	}
	if err := os.Remove(path); err != nil {
		return nil, failure("storage_error")
	}
	body, _ := json.Marshal(map[string]string{"code": args.Code, "code_verifier": pending.Verifier})
	response, err := a.request(ctx, http.MethodPost, "/api/user/client-login/token", body, "", 64*1024)
	if err != nil {
		return nil, err
	}
	var account credentials
	if json.Unmarshal(response, &account) != nil || !validCredentials(account) {
		return nil, failure("invalid_response")
	}
	account.Site = a.site
	if err := writeJSON(filepath.Join(a.dataDir, "session.json"), account); err != nil {
		return nil, failure("storage_error")
	}
	return map[string]any{"email": account.Email}, nil
}

func (a *app) cancelLogin(args arguments) (any, error) {
	var pending pendingLogin
	path := filepath.Join(a.runDir, "login.json")
	if readJSON(path, &pending) == nil && pending.Session == digest(args.Session) {
		if err := os.Remove(path); err != nil {
			return nil, failure("storage_error")
		}
	}
	return nil, nil
}

func (a *app) request(ctx context.Context, method, path string, body []byte, key string, limit int64) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, a.site+path, bytes.NewReader(body))
	if err != nil {
		return nil, failure("invalid_response")
	}
	req.Header.Set("User-Agent", "iPing Linux Clash.Meta")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if key != "" {
		req.Header.Set("Authorization", "Bearer "+key)
	}
	client := a.client
	// The Agent bypasses its own TUN; fake DNS addresses require the Core's proxy resolver.
	if a.core != nil && a.running(ctx) {
		proxy, err := a.probeProxy(ctx, false)
		if err == nil {
			transport := http.DefaultTransport.(*http.Transport).Clone()
			if base, ok := a.client.Transport.(*http.Transport); ok {
				transport = base.Clone()
			}
			transport.Proxy = http.ProxyURL(proxy)
			defer transport.CloseIdleConnections()
			routed := *a.client
			routed.Transport = transport
			client = &routed
		}
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, failure("network_error")
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return nil, failure("login_required")
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, failure("request_failed")
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil || int64(len(data)) > limit {
		return nil, failure("invalid_response")
	}
	return data, nil
}

func (a *app) siteConfig(ctx context.Context) (any, error) {
	data, err := a.request(ctx, http.MethodGet, "/api/system/config/site", nil, "", 64*1024)
	if err != nil {
		return nil, err
	}
	var config map[string]any
	if json.Unmarshal(data, &config) != nil {
		return nil, failure("invalid_response")
	}
	result := map[string]any{}
	for _, key := range []string{"SITE_NAME", "SITE_DESCRIPTION", "LOGO_URL", "ALLOW_REGISTER"} {
		if value, exists := config[key]; exists {
			result[key] = value
		}
	}
	return result, nil
}

func (a *app) userInfo(ctx context.Context) (any, error) {
	account, err := a.account()
	if err != nil {
		return nil, err
	}
	data, err := a.request(ctx, http.MethodGet, "/api/user/info", nil, account.AccessKey, 256*1024)
	if err != nil {
		return nil, err
	}
	var info struct {
		ID      int64   `json:"id"`
		Email   string  `json:"email"`
		Balance float64 `json:"balance"`
		Status  string  `json:"status"`
	}
	if json.Unmarshal(data, &info) != nil || info.ID != account.ID {
		return nil, failure("invalid_response")
	}
	return info, nil
}
