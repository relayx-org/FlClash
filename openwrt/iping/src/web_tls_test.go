package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestWebCertificateSurvivesRestartAndRenewsForAddressChanges(t *testing.T) {
	path := filepath.Join(t.TempDir(), "web-tls.pem")
	addresses := []net.IP{net.IPv4(127, 0, 0, 1), net.IPv6loopback, net.ParseIP("192.168.1.1")}
	now := time.Now()
	first, err := webCertificate(path, addresses, now)
	if err != nil {
		t.Fatal(err)
	}
	leaf, err := x509.ParseCertificate(first.Certificate[0])
	if err != nil || leaf.VerifyHostname("192.168.1.1") != nil || leaf.VerifyHostname("localhost") != nil {
		t.Fatalf("invalid certificate: %v", err)
	}
	info, err := os.Stat(path)
	if err != nil || info.Mode().Perm() != 0600 {
		t.Fatal("TLS private key is not private")
	}
	restarted, err := webCertificate(path, addresses, now.Add(time.Hour))
	if err != nil || !bytes.Equal(first.Certificate[0], restarted.Certificate[0]) {
		t.Fatal("certificate changed on restart")
	}
	renewed, err := webCertificate(path, addresses, now.Add(360*24*time.Hour))
	if err != nil || bytes.Equal(first.Certificate[0], renewed.Certificate[0]) {
		t.Fatal("expiring certificate was not renewed")
	}
	addresses = append(addresses, net.ParseIP("192.168.2.1"))
	changed, err := webCertificate(path, addresses, now.Add(360*24*time.Hour))
	if err != nil || bytes.Equal(renewed.Certificate[0], changed.Certificate[0]) {
		t.Fatal("new LAN address was not added")
	}
	if err := os.WriteFile(path, []byte("invalid key"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := webCertificate(path, addresses, now); err == nil {
		t.Fatal("damaged key was silently replaced")
	}
}

func TestWebTLSListenerIsOptionalAndValidatesItsAddress(t *testing.T) {
	a := &app{dataDir: t.TempDir()}
	for _, value := range []string{"", "localhost:443", "0.0.0.0:0", "0.0.0.0:65536", "bad"} {
		a.command = func(context.Context, string, ...string) ([]byte, error) { return []byte(value), nil }
		listener, _, err := a.webTLS(context.Background())
		if listener != nil {
			listener.Close()
			t.Fatal("invalid listener was opened")
		}
		if (value == "") != (err == nil) {
			t.Fatalf("unexpected validation for %q: %v", value, err)
		}
	}
	a.command = func(context.Context, string, ...string) ([]byte, error) { return nil, errors.New("missing") }
	if listener, _, err := a.webTLS(context.Background()); listener != nil || err != nil {
		t.Fatal("old configurations must keep HTTP without enabling TLS")
	}
	if _, err := os.Stat(filepath.Join(a.dataDir, "web-tls.pem")); !os.IsNotExist(err) {
		t.Fatal("disabled TLS created a private key")
	}
}

func TestWebTLSAlwaysIsolatesItsPages(t *testing.T) {
	for _, query := range []string{"", "?isolation=0", "?diagnostics=1&isolation=0", "?diagnostics=1&compare=1&isolation=0"} {
		request := httptest.NewRequest(http.MethodGet, "https://router/"+query, nil)
		request.TLS = &tls.ConnectionState{}
		request.RemoteAddr = "192.168.1.2:1234"
		response := httptest.NewRecorder()
		(&app{}).webHandler().ServeHTTP(response, request)
		expected := "same-origin"
		if response.Header().Get("Cross-Origin-Opener-Policy") != expected {
			t.Fatalf("unexpected isolation for %q", query)
		}
	}
}

func TestWebTLSKeepsOriginChecksAndSecuresBrowserSessions(t *testing.T) {
	f := testSetup(t, false)
	certificate, err := webCertificate(filepath.Join(f.a.dataDir, "web-tls.pem"), []net.IP{net.IPv4(127, 0, 0, 1)}, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewUnstartedServer(f.a.webHandler())
	server.TLS = &tls.Config{MinVersion: tls.VersionTLS12, Certificates: []tls.Certificate{certificate}}
	server.StartTLS()
	defer server.Close()
	for _, origin := range []string{server.URL, strings.Replace(server.URL, "https:", "http:", 1), "https://other.test"} {
		request, _ := http.NewRequest(http.MethodPost, server.URL+"/api/status", strings.NewReader(`{}`))
		request.Header.Set("Origin", origin)
		response, err := server.Client().Do(request)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.Copy(io.Discard, response.Body)
		response.Body.Close()
		if response.Header.Get("Cross-Origin-Opener-Policy") != "same-origin" || response.Header.Get("Cross-Origin-Embedder-Policy") != "require-corp" {
			t.Fatal("HTTPS response is not isolated")
		}
		if origin != server.URL {
			if response.StatusCode != http.StatusForbidden {
				t.Fatal("cross-origin TLS request accepted")
			}
			continue
		}
		cookies := response.Cookies()
		if response.StatusCode != 200 || len(cookies) != 1 || cookies[0].Name != "iping_secure_session" || !cookies[0].Secure || !cookies[0].HttpOnly || cookies[0].SameSite != http.SameSiteStrictMode {
			t.Fatal("HTTPS browser session is not secure")
		}
		plain := httptest.NewRequest(http.MethodPost, "http://router/api/status", nil)
		plain.AddCookie(cookies[0])
		writer := httptest.NewRecorder()
		id, err := browserSession(writer, plain)
		if err != nil || id == cookies[0].Value || writer.Result().Cookies()[0].Name != "iping_session" {
			t.Fatal("HTTP and HTTPS overwrite each other's browser sessions")
		}
	}
}
