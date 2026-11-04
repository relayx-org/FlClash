package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	// Mihomo keeps its own DNS server on loopback while the Agent owns the
	// client-facing listener, so Mihomo's TUN hijack path stays untouched.
	mihomoDNSListen = "127.0.0.1:1054"
	dnsQueryLimit   = 200
)

type dnsQuestion struct {
	Name  string
	Type  uint16
	Class uint16
}

type dnsQueryEntry struct {
	Domain    string    `json:"domain"`
	Type      string    `json:"type"`
	Initiator string    `json:"initiator"`
	Upstream  string    `json:"upstream"`
	Cached    bool      `json:"cached"`
	Answers   []string  `json:"answers"`
	Rcode     string    `json:"rcode,omitempty"`
	Error     string    `json:"error,omitempty"`
	Delay     int64     `json:"delay"`
	Time      time.Time `json:"time"`
	Client    string    `json:"client,omitempty"`
	Protocol  string    `json:"protocol,omitempty"`
}

type dnsProxy struct {
	app      *app
	listen   string
	upstream string
	udp      net.PacketConn
	tcp      net.Listener
	sem      chan struct{}
	closed   chan struct{}
	once     sync.Once
	wg       sync.WaitGroup
}

func (a *app) recordDNSQuery(entry dnsQueryEntry) {
	if entry.Answers == nil {
		entry.Answers = []string{}
	}
	if entry.Initiator == "" {
		entry.Initiator = "other"
	}
	entry.Time = entry.Time.Truncate(time.Millisecond)
	a.dnsMu.Lock()
	defer a.dnsMu.Unlock()
	a.dnsQueryLog = append(a.dnsQueryLog, entry)
	if len(a.dnsQueryLog) > dnsQueryLimit {
		a.dnsQueryLog = append([]dnsQueryEntry(nil), a.dnsQueryLog[len(a.dnsQueryLog)-dnsQueryLimit:]...)
	}
}

func (a *app) dnsQueryHistory() []dnsQueryEntry {
	a.dnsMu.Lock()
	defer a.dnsMu.Unlock()
	items := make([]dnsQueryEntry, len(a.dnsQueryLog))
	copy(items, a.dnsQueryLog)
	for left, right := 0, len(items)-1; left < right; left, right = left+1, right-1 {
		items[left], items[right] = items[right], items[left]
	}
	return items
}

func (a *app) dnsQueries() (any, error) {
	items := a.dnsQueryHistory()
	return map[string]any{"items": items, "limit": dnsQueryLimit, "total": len(items)}, nil
}

func (a *app) storedDNSProxyConfig() (string, bool) {
	enabled := true
	listen := "127.0.0.1:1053"
	if spec, ok := settingsSpec["dns.listen"]; ok {
		if value, ok := spec.Default.(string); ok && value != "" {
			listen = value
		}
	}
	values, err := a.storedProfileSettings()
	if err != nil {
		return listen, enabled
	}
	if value, ok := values["dns.enable"].(bool); ok {
		enabled = value
	}
	if value, ok := values["dns.listen"].(string); ok && strings.TrimSpace(value) != "" {
		listen = value
	}
	return listen, enabled
}

func (a *app) startRuntimeDNSProxy() error {
	listen, enabled := a.storedDNSProxyConfig()
	if !enabled {
		a.stopDNSProxy()
		return nil
	}
	_, port, err := net.SplitHostPort(listen)
	number, parseErr := strconv.Atoi(port)
	if err != nil || parseErr != nil || number < 1024 || number > 65535 || number == 1054 {
		return failure("invalid_request")
	}
	return a.startDNSProxy(listen, mihomoDNSListen)
}

func (a *app) startDNSProxy(listen, upstream string) error {
	a.stopDNSProxy()
	proxy, err := newDNSProxy(a, listen, upstream)
	if err != nil {
		return failure("service_failed")
	}
	a.dnsMu.Lock()
	a.dnsProxy = proxy
	a.dnsMu.Unlock()
	return nil
}

func (a *app) stopDNSProxy() {
	a.dnsMu.Lock()
	proxy := a.dnsProxy
	a.dnsProxy = nil
	a.dnsMu.Unlock()
	if proxy != nil {
		proxy.close()
	}
}

func newDNSProxy(a *app, listen, upstream string) (*dnsProxy, error) {
	udp, err := net.ListenPacket("udp", listen)
	if err != nil {
		return nil, err
	}
	tcp, err := net.Listen("tcp", listen)
	if err != nil {
		udp.Close()
		return nil, err
	}
	proxy := &dnsProxy{
		app: a, listen: listen, upstream: upstream,
		udp: udp, tcp: tcp, sem: make(chan struct{}, 128), closed: make(chan struct{}),
	}
	proxy.wg.Add(2)
	go proxy.serveUDP()
	go proxy.serveTCP()
	return proxy, nil
}

func (p *dnsProxy) close() {
	p.once.Do(func() {
		close(p.closed)
		p.udp.Close()
		p.tcp.Close()
	})
	p.wg.Wait()
}

func (p *dnsProxy) acquire() bool {
	select {
	case p.sem <- struct{}{}:
		return true
	case <-p.closed:
		return false
	}
}

func (p *dnsProxy) release() { <-p.sem }

func (p *dnsProxy) serveUDP() {
	defer p.wg.Done()
	buffer := make([]byte, 64*1024)
	for {
		n, address, err := p.udp.ReadFrom(buffer)
		if err != nil {
			select {
			case <-p.closed:
				return
			default:
			}
			if errors.Is(err, net.ErrClosed) {
				return
			}
			continue
		}
		if !p.acquire() {
			return
		}
		data := append([]byte(nil), buffer[:n]...)
		go func() {
			defer p.release()
			p.handleUDP(data, address)
		}()
	}
}

func (p *dnsProxy) handleUDP(query []byte, address net.Addr) {
	start := time.Now()
	response, err := p.exchange(query, "udp")
	p.observe(address.String(), "udp", start, query, response, err)
	if err != nil || len(response) == 0 {
		response = dnsFailureResponse(query)
	}
	if len(response) > 0 {
		_, _ = p.udp.WriteTo(response, address)
	}
}

func (p *dnsProxy) serveTCP() {
	defer p.wg.Done()
	for {
		conn, err := p.tcp.Accept()
		if err != nil {
			select {
			case <-p.closed:
				return
			default:
			}
			if errors.Is(err, net.ErrClosed) {
				return
			}
			continue
		}
		if !p.acquire() {
			conn.Close()
			return
		}
		go func() {
			defer p.release()
			p.handleTCP(conn)
		}()
	}
}

func (p *dnsProxy) handleTCP(conn net.Conn) {
	defer conn.Close()
	for {
		_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
		length := uint16(0)
		if err := binary.Read(conn, binary.BigEndian, &length); err != nil {
			return
		}
		if length == 0 {
			return
		}
		query := make([]byte, length)
		if _, err := io.ReadFull(conn, query); err != nil {
			return
		}
		start := time.Now()
		response, err := p.exchange(query, "tcp")
		p.observe(conn.RemoteAddr().String(), "tcp", start, query, response, err)
		if err != nil || len(response) == 0 {
			response = dnsFailureResponse(query)
		}
		if len(response) > 65535 {
			response = response[:65535]
		}
		if err := binary.Write(conn, binary.BigEndian, uint16(len(response))); err != nil {
			return
		}
		if _, err := conn.Write(response); err != nil {
			return
		}
	}
}

func (p *dnsProxy) exchange(query []byte, network string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := (&net.Dialer{}).DialContext(ctx, network, p.upstream)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	deadline, _ := ctx.Deadline()
	_ = conn.SetDeadline(deadline)
	if network == "tcp" {
		if err := binary.Write(conn, binary.BigEndian, uint16(len(query))); err != nil {
			return nil, err
		}
	}
	if _, err := conn.Write(query); err != nil {
		return nil, err
	}
	if network == "tcp" {
		var length uint16
		if err := binary.Read(conn, binary.BigEndian, &length); err != nil {
			return nil, err
		}
		response := make([]byte, length)
		if _, err := io.ReadFull(conn, response); err != nil {
			return nil, err
		}
		return response, nil
	}
	buffer := make([]byte, 64*1024)
	n, err := conn.Read(buffer)
	if err != nil {
		return nil, err
	}
	return append([]byte(nil), buffer[:n]...), nil
}

func (p *dnsProxy) observe(client, protocol string, start time.Time, query, response []byte, err error) {
	question, _, ok := parseDNSQuestion(query)
	if !ok {
		return
	}
	entry := dnsQueryEntry{
		Domain: question.Name, Type: dnsTypeName(question.Type), Initiator: "other",
		Upstream: p.upstream, Answers: []string{}, Time: start,
		Delay: time.Since(start).Milliseconds(), Client: client, Protocol: protocol,
	}
	if err != nil {
		entry.Error = limitText(err.Error(), 256)
	} else if rcode, answers, ok := parseDNSResponse(response); ok {
		entry.Rcode = rcode
		entry.Answers = answers
	}
	p.app.recordDNSQuery(entry)
}

func limitText(value string, limit int) string {
	if len(value) <= limit {
		return value
	}
	return value[:limit]
}

func dnsFailureResponse(query []byte) []byte {
	_, end, ok := parseDNSQuestion(query)
	if !ok || end > len(query) || end < 12 {
		return nil
	}
	response := append([]byte(nil), query[:end]...)
	flags := binary.BigEndian.Uint16(response[2:4])
	flags |= 0x8000
	flags |= 0x0080
	flags &^= 0x000f
	flags |= 2
	binary.BigEndian.PutUint16(response[2:4], flags)
	for _, offset := range []int{6, 8, 10} {
		binary.BigEndian.PutUint16(response[offset:offset+2], 0)
	}
	return response
}

func parseDNSQuestion(message []byte) (dnsQuestion, int, bool) {
	question := dnsQuestion{}
	if len(message) < 12 || binary.BigEndian.Uint16(message[4:6]) == 0 {
		return question, 0, false
	}
	name, offset, ok := readDNSName(message, 12)
	if !ok || offset+4 > len(message) {
		return question, 0, false
	}
	question.Name = name
	question.Type = binary.BigEndian.Uint16(message[offset : offset+2])
	question.Class = binary.BigEndian.Uint16(message[offset+2 : offset+4])
	return question, offset + 4, true
}

func parseDNSResponse(message []byte) (string, []string, bool) {
	if len(message) < 12 {
		return "", nil, false
	}
	flags := binary.BigEndian.Uint16(message[2:4])
	if flags&0x8000 == 0 {
		return "", nil, false
	}
	rcode := dnsRcodeName(int(flags & 0x000f))
	questions := int(binary.BigEndian.Uint16(message[4:6]))
	answers := int(binary.BigEndian.Uint16(message[6:8]))
	offset := 12
	for index := 0; index < questions; index++ {
		_, next, ok := readDNSName(message, offset)
		if !ok || next+4 > len(message) {
			return rcode, nil, false
		}
		offset = next + 4
	}
	values := []string{}
	for index := 0; index < answers && index < 64; index++ {
		_, next, ok := readDNSName(message, offset)
		if !ok || next+10 > len(message) {
			break
		}
		rrType := binary.BigEndian.Uint16(message[next : next+2])
		length := int(binary.BigEndian.Uint16(message[next+8 : next+10]))
		dataOffset := next + 10
		if dataOffset+length > len(message) {
			break
		}
		if value := dnsAnswerValue(message, dataOffset, length, rrType); value != "" {
			values = append(values, value)
		}
		offset = dataOffset + length
	}
	return rcode, values, true
}

func dnsAnswerValue(message []byte, offset, length int, rrType uint16) string {
	switch rrType {
	case 1:
		if length == 4 {
			return net.IP(message[offset : offset+length]).String()
		}
	case 28:
		if length == 16 {
			return net.IP(message[offset : offset+length]).String()
		}
	case 5, 2, 12:
		name, _, ok := readDNSName(message, offset)
		if ok {
			return name
		}
	case 16:
		parts := []string{}
		for index := offset; index < offset+length; {
			size := int(message[index])
			index++
			if index+size > offset+length {
				break
			}
			parts = append(parts, string(message[index:index+size]))
			index += size
		}
		return strings.Join(parts, " ")
	case 15:
		if length >= 3 {
			name, _, ok := readDNSName(message, offset+2)
			if ok {
				return fmt.Sprintf("%d %s", binary.BigEndian.Uint16(message[offset:offset+2]), name)
			}
		}
	}
	return ""
}

func readDNSName(message []byte, offset int) (string, int, bool) {
	labels := []string{}
	next := offset
	jumped := false
	for steps := 0; steps < 128; steps++ {
		if offset >= len(message) {
			return "", 0, false
		}
		length := int(message[offset])
		if length == 0 {
			if !jumped {
				next = offset + 1
			}
			if total := len(strings.Join(labels, ".")); total > 255 {
				return "", 0, false
			}
			return strings.Join(labels, "."), next, true
		}
		if length&0xc0 == 0xc0 {
			if offset+1 >= len(message) {
				return "", 0, false
			}
			if !jumped {
				next = offset + 2
				jumped = true
			}
			pointer := int(message[offset]&0x3f)<<8 | int(message[offset+1])
			if pointer >= len(message) {
				return "", 0, false
			}
			offset = pointer
			continue
		}
		if length&0xc0 != 0 || offset+1+length > len(message) {
			return "", 0, false
		}
		labels = append(labels, string(message[offset+1:offset+1+length]))
		offset += 1 + length
	}
	return "", 0, false
}

func dnsTypeName(value uint16) string {
	names := map[uint16]string{
		1: "A", 2: "NS", 5: "CNAME", 6: "SOA", 12: "PTR", 15: "MX", 16: "TXT",
		28: "AAAA", 33: "SRV", 65: "HTTPS", 64: "SVCB", 255: "ANY",
	}
	if name, ok := names[value]; ok {
		return name
	}
	return fmt.Sprintf("TYPE%d", value)
}

func dnsRcodeName(value int) string {
	names := map[int]string{
		0: "NOERROR", 1: "FORMERR", 2: "SERVFAIL", 3: "NXDOMAIN",
		4: "NOTIMP", 5: "REFUSED",
	}
	if name, ok := names[value]; ok {
		return name
	}
	return fmt.Sprintf("RCODE%d", value)
}
