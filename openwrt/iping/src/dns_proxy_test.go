package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"go.yaml.in/yaml/v3"
)

func testDNSName(name string) []byte {
	result := []byte{}
	for _, label := range strings.Split(strings.TrimSuffix(name, "."), ".") {
		if label == "" {
			continue
		}
		result = append(result, byte(len(label)))
		result = append(result, label...)
	}
	return append(result, 0)
}

func testDNSQuery(name string, qtype uint16) []byte {
	packet := make([]byte, 12)
	binary.BigEndian.PutUint16(packet[0:2], 0x1234)
	binary.BigEndian.PutUint16(packet[2:4], 0x0100)
	binary.BigEndian.PutUint16(packet[4:6], 1)
	packet = append(packet, testDNSName(name)...)
	packet = binary.BigEndian.AppendUint16(packet, qtype)
	packet = binary.BigEndian.AppendUint16(packet, 1)
	return packet
}

func testDNSAnswer(rrtype uint16, data []byte) []byte {
	answer := []byte{0xc0, 0x0c}
	answer = binary.BigEndian.AppendUint16(answer, rrtype)
	answer = binary.BigEndian.AppendUint16(answer, 1)
	answer = binary.BigEndian.AppendUint32(answer, 60)
	answer = binary.BigEndian.AppendUint16(answer, uint16(len(data)))
	return append(answer, data...)
}

func testDNSResponse(query []byte, rcode int, answers ...[]byte) []byte {
	question, end, ok := parseDNSQuestion(query)
	if !ok {
		return nil
	}
	packet := append([]byte(nil), query[:2]...)
	packet = binary.BigEndian.AppendUint16(packet, uint16(0x8180|rcode))
	packet = binary.BigEndian.AppendUint16(packet, 1)
	packet = binary.BigEndian.AppendUint16(packet, uint16(len(answers)))
	packet = binary.BigEndian.AppendUint16(packet, 0)
	packet = binary.BigEndian.AppendUint16(packet, 0)
	packet = append(packet, query[12:end]...)
	if question.Name == "" {
		return nil
	}
	for _, answer := range answers {
		packet = append(packet, answer...)
	}
	return packet
}

func startDNSUpstream(t *testing.T) (string, func()) {
	t.Helper()
	tcp, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := tcp.Addr().String()
	udp, err := net.ListenPacket("udp", address)
	if err != nil {
		tcp.Close()
		t.Fatal(err)
	}
	responseFor := func(query []byte) []byte {
		answer := testDNSAnswer(1, []byte{203, 0, 113, 7})
		return testDNSResponse(query, 0, answer)
	}
	done := make(chan struct{})
	go func() {
		for {
			buffer := make([]byte, 4096)
			n, remote, err := udp.ReadFrom(buffer)
			if err != nil {
				return
			}
			response := responseFor(buffer[:n])
			if response != nil {
				_, _ = udp.WriteTo(response, remote)
			}
		}
	}()
	go func() {
		for {
			conn, err := tcp.Accept()
			if err != nil {
				return
			}
			go func() {
				defer conn.Close()
				for {
					var length uint16
					if err := binary.Read(conn, binary.BigEndian, &length); err != nil {
						return
					}
					query := make([]byte, length)
					if _, err := io.ReadFull(conn, query); err != nil {
						return
					}
					response := responseFor(query)
					if response == nil {
						return
					}
					_ = binary.Write(conn, binary.BigEndian, uint16(len(response)))
					_, _ = conn.Write(response)
				}
			}()
		}
	}()
	return address, func() {
		close(done)
		udp.Close()
		tcp.Close()
	}
}

func TestDNSProxyRecordsUDPAndTCPQueries(t *testing.T) {
	upstream, stop := startDNSUpstream(t)
	defer stop()
	a := &app{}
	if err := a.startDNSProxy("127.0.0.1:0", upstream); err != nil {
		t.Fatal(err)
	}
	defer a.stopDNSProxy()
	a.dnsMu.Lock()
	proxy := a.dnsProxy
	a.dnsMu.Unlock()
	if proxy == nil {
		t.Fatal("missing proxy")
	}

	query := testDNSQuery("www.example.com", 1)
	udpConn, err := net.Dial("udp", proxy.udp.LocalAddr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer udpConn.Close()
	_ = udpConn.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := udpConn.Write(query); err != nil {
		t.Fatal(err)
	}
	response := make([]byte, 4096)
	n, err := udpConn.Read(response)
	if err != nil {
		t.Fatal(err)
	}
	rcode, answers, ok := parseDNSResponse(response[:n])
	if !ok || rcode != "NOERROR" || fmt.Sprint(answers) != "[203.0.113.7]" {
		t.Fatalf("udp response = %q %v %v", rcode, answers, ok)
	}

	tcpConn, err := net.Dial("tcp", proxy.tcp.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer tcpConn.Close()
	_ = tcpConn.SetDeadline(time.Now().Add(2 * time.Second))
	_ = binary.Write(tcpConn, binary.BigEndian, uint16(len(query)))
	if _, err := tcpConn.Write(query); err != nil {
		t.Fatal(err)
	}
	var length uint16
	if err := binary.Read(tcpConn, binary.BigEndian, &length); err != nil {
		t.Fatal(err)
	}
	response = make([]byte, length)
	if _, err := io.ReadFull(tcpConn, response); err != nil {
		t.Fatal(err)
	}
	if rcode, answers, ok := parseDNSResponse(response); !ok || rcode != "NOERROR" || fmt.Sprint(answers) != "[203.0.113.7]" {
		t.Fatalf("tcp response = %q %v %v", rcode, answers, ok)
	}

	waitUntil(t, func() bool { return len(a.dnsQueryHistory()) >= 2 })
	for _, entry := range a.dnsQueryHistory() {
		if entry.Domain != "www.example.com" || entry.Type != "A" || entry.Rcode != "NOERROR" ||
			entry.Upstream != upstream || fmt.Sprint(entry.Answers) != "[203.0.113.7]" ||
			entry.Client == "" || entry.Delay < 0 {
			t.Fatalf("entry = %+v", entry)
		}
		if entry.Protocol != "udp" && entry.Protocol != "tcp" {
			t.Fatalf("protocol = %q", entry.Protocol)
		}
	}
}

func TestDNSResponseParsingAndFailureResponse(t *testing.T) {
	query := testDNSQuery("www.example.com", 1)
	cname := testDNSAnswer(5, testDNSName("edge.example.net"))
	address := testDNSAnswer(1, []byte{203, 0, 113, 9})
	response := testDNSResponse(query, 0, cname, address)
	rcode, answers, ok := parseDNSResponse(response)
	if !ok || rcode != "NOERROR" || fmt.Sprint(answers) != "[edge.example.net 203.0.113.9]" {
		t.Fatalf("response = %q %v %v", rcode, answers, ok)
	}
	rcode, answers, ok = parseDNSResponse(testDNSResponse(query, 3))
	if !ok || rcode != "NXDOMAIN" || len(answers) != 0 {
		t.Fatalf("nxdomain = %q %v %v", rcode, answers, ok)
	}
	failure := dnsFailureResponse(query)
	if rcode, _, ok := parseDNSResponse(failure); !ok || rcode != "SERVFAIL" {
		t.Fatalf("failure response = %x", failure)
	}
	if !bytes.Equal(failure[:2], query[:2]) || binary.BigEndian.Uint16(failure[4:6]) != 1 {
		t.Fatalf("failure response did not preserve the query: %x", failure)
	}
}

func TestDNSHistoryIsBoundedAndNewestFirst(t *testing.T) {
	a := &app{}
	for index := 0; index < dnsQueryLimit+10; index++ {
		a.recordDNSQuery(dnsQueryEntry{Domain: fmt.Sprint(index), Time: time.Now()})
	}
	items := a.dnsQueryHistory()
	if len(items) != dnsQueryLimit {
		t.Fatalf("history length = %d", len(items))
	}
	if items[0].Domain != fmt.Sprint(dnsQueryLimit+9) || items[len(items)-1].Domain != "10" {
		t.Fatalf("history order = %s .. %s", items[0].Domain, items[len(items)-1].Domain)
	}
	if items[0].Initiator != "other" || items[0].Answers == nil {
		t.Fatalf("entry defaults = %+v", items[0])
	}
}

func TestProfileRoutesDNSThroughTheAgentListener(t *testing.T) {
	a := &app{
		dataDir: t.TempDir(), runDir: t.TempDir(),
		controllerAddress: "127.0.0.1:19090",
	}
	source := []byte("proxies: [{name: fixture, type: direct}]\nrules: ['MATCH,DIRECT']\ndns: {listen: 0.0.0.0:1053}\n")
	data, err := a.buildProfile(source, nil)
	if err != nil {
		t.Fatal(err)
	}
	var profile map[string]any
	if yaml.Unmarshal(data, &profile) != nil {
		t.Fatal("invalid profile")
	}
	if yamlSetting(profile, "dns.listen") != mihomoDNSListen {
		t.Fatalf("dns.listen = %v", yamlSetting(profile, "dns.listen"))
	}
	if yamlSetting(profile, "tun.dns-hijack") == nil {
		t.Fatal("TUN DNS hijack was removed")
	}
	if _, err := a.buildProfile(source, map[string]any{"dns.listen": "0.0.0.0:5353"}); err != nil {
		t.Fatal(err)
	}
	for _, listen := range []string{mihomoDNSListen, "0.0.0.0:19090", "0.0.0.0:7890"} {
		if _, err := a.buildProfile(source, map[string]any{"dns.listen": listen}); err == nil {
			t.Fatalf("conflicting DNS listener accepted: %s", listen)
		}
	}
}

func TestManagedResourcesStayInsideWhitelistedRoots(t *testing.T) {
	a := &app{dataDir: t.TempDir()}
	if err := os.WriteFile(filepath.Join(a.dataDir, "GeoIP.dat"), []byte("geo"), 0600); err != nil {
		t.Fatal(err)
	}
	providerDir := filepath.Join(a.dataDir, "rule-providers")
	if err := os.MkdirAll(providerDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(providerDir, "ads.yaml"), []byte("payload"), 0600); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(t.TempDir(), "secret")
	if err := os.WriteFile(outside, []byte("secret"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(providerDir, "outside")); err != nil {
		t.Fatal(err)
	}
	result, err := a.resources(context.Background(), arguments{})
	if err != nil {
		t.Fatal(err)
	}
	items := result.(map[string]any)["items"].([]managedResource)
	found := map[string]bool{}
	for _, item := range items {
		found[item.Path] = true
		if filepath.IsAbs(item.Path) || strings.Contains(item.Path, "..") || strings.Contains(item.Path, "secret") {
			t.Fatalf("unsafe resource path: %+v", item)
		}
	}
	if !found["GeoIP.dat"] || !found["rule-providers/ads.yaml"] || found["rule-providers/outside"] {
		t.Fatalf("resources = %+v", items)
	}
	if _, err := a.resources(context.Background(), arguments{Action: "delete"}); err == nil {
		t.Fatal("unknown action accepted")
	}
	if _, err := a.resources(context.Background(), arguments{Action: "refresh"}); err == nil || err.Error() != "controller_unavailable" {
		t.Fatalf("refresh without Core = %v", err)
	}
}

func TestResourceRefreshUpdatesProvidersAndCaches(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPut && (r.URL.Path == "/providers/rules/Ads" || r.URL.Path == "/providers/proxies/Proxy"):
			w.WriteHeader(http.StatusNoContent)
		case r.Method == http.MethodPost && (r.URL.Path == "/cache/dns/flush" || r.URL.Path == "/cache/fakeip/flush"):
			w.WriteHeader(http.StatusNoContent)
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()
	address := strings.TrimPrefix(server.URL, "http://")
	a := &app{
		dataDir: t.TempDir(), runDir: t.TempDir(),
		profile: filepath.Join(t.TempDir(), "profile.yaml"), runProfile: filepath.Join(t.TempDir(), "config.yaml"),
		site: "https://example.com", client: server.Client(), ctx: context.Background(),
	}
	if err := writeJSON(filepath.Join(a.dataDir, "session.json"), credentials{
		ID: 1, Email: "user@example.com", SubscriptionToken: "token",
		AccessKey: "11111111-1111-1111-1111-111111111111", Site: a.site,
	}); err != nil {
		t.Fatal(err)
	}
	config := "external-controller: " + address + "\nsecret: private\nrule-providers:\n  Ads: {}\nproxy-providers:\n  Proxy: {}\n"
	if err := writePrivate(a.runProfile, []byte(config)); err != nil {
		t.Fatal(err)
	}
	a.core = &coreRuntime{}
	child := &coreChild{done: make(chan struct{})}
	child.ready.Store(true)
	a.core.current.Store(child)
	result, err := a.resources(context.Background(), arguments{Action: "refresh"})
	if err != nil {
		t.Fatal(err)
	}
	data := result.(map[string]any)
	if data["updated"] != 4 || len(data["failures"].([]string)) != 0 {
		t.Fatalf("refresh = %+v", data)
	}
}
