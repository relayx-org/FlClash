package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"time"
)

func webCertificate(path string, addresses []net.IP, now time.Time) (tls.Certificate, error) {
	data, err := os.ReadFile(path)
	if err == nil {
		certificate, err := tls.X509KeyPair(data, data)
		if err != nil {
			return tls.Certificate{}, err
		}
		leaf, err := x509.ParseCertificate(certificate.Certificate[0])
		if err != nil {
			return tls.Certificate{}, err
		}
		valid := leaf.NotAfter.After(now.Add(7 * 24 * time.Hour))
		for _, address := range addresses {
			valid = valid && leaf.VerifyHostname(address.String()) == nil
		}
		if valid {
			return certificate, os.Chmod(path, 0600)
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return tls.Certificate{}, err
	}
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, err
	}
	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return tls.Certificate{}, err
	}
	template := &x509.Certificate{
		SerialNumber:          serial,
		Subject:               pkix.Name{CommonName: "iPing local Web interface"},
		NotBefore:             now.Add(-5 * time.Minute),
		NotAfter:              now.Add(365 * 24 * time.Hour),
		IPAddresses:           addresses,
		DNSNames:              []string{"localhost"},
		KeyUsage:              x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return tls.Certificate{}, err
	}
	private, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return tls.Certificate{}, err
	}
	data = append(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}),
		pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: private})...)
	if err := writePrivate(path, data); err != nil {
		return tls.Certificate{}, err
	}
	return tls.X509KeyPair(data, data)
}

func (a *app) webTLS(ctx context.Context) (net.Listener, *tls.Config, error) {
	address, err := a.webListenAddress(ctx, "web_tls_listen", "", 1)
	if err != nil || address == "" {
		return nil, nil, err
	}
	addresses := []net.IP{net.IPv4(127, 0, 0, 1), net.IPv6loopback}
	interfaces, err := net.InterfaceAddrs()
	if err != nil {
		return nil, nil, err
	}
	for _, item := range interfaces {
		ip, _, err := net.ParseCIDR(item.String())
		if err == nil && (ip.IsPrivate() || ip.IsLinkLocalUnicast()) {
			addresses = append(addresses, ip)
		}
	}
	certificate, err := webCertificate(filepath.Join(a.dataDir, "web-tls.pem"), addresses, time.Now())
	if err != nil {
		return nil, nil, err
	}
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return nil, nil, err
	}
	return listener, &tls.Config{MinVersion: tls.VersionTLS12, Certificates: []tls.Certificate{certificate}}, nil
}
