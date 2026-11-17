package main

import (
	"compress/gzip"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
)

//go:embed all:geodata
var bundledGeodata embed.FS

var geoFilenames = map[string]string{
	"GEOIP.metadb": "geoip.metadb",
	"GEOIP.dat":    "GeoIP.dat",
	"GEOSITE.dat":  "GeoSite.dat",
	"ASN.mmdb":     "ASN.mmdb",
}

func installBundledGeodata(files fs.FS, home string) error {
	data, err := fs.ReadFile(files, "geodata/manifest.json")
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var manifest struct {
		Files map[string]struct {
			SHA256 string `json:"sha256"`
			Size   int64  `json:"size"`
		} `json:"files"`
	}
	if err := json.Unmarshal(data, &manifest); err != nil {
		return err
	}
	if len(manifest.Files) != len(geoFilenames) {
		return fmt.Errorf("incomplete bundled geodata")
	}
	for name, filename := range geoFilenames {
		metadata, ok := manifest.Files[name]
		if !ok || metadata.Size <= 0 || len(metadata.SHA256) != 64 {
			return fmt.Errorf("invalid bundled geodata: %s", name)
		}
		target := filepath.Join(home, filename)
		marker := target + ".bundled.sha256"
		previous, _ := os.ReadFile(marker)
		if _, err := os.Stat(target); err == nil && string(previous) == metadata.SHA256 {
			continue
		}
		if err := installGeoFile(files, name, target, metadata.SHA256, metadata.Size); err != nil {
			return err
		}
		if err := writePrivate(marker, []byte(metadata.SHA256)); err != nil {
			return err
		}
	}
	return nil
}

func installGeoFile(files fs.FS, name, target, digest string, size int64) error {
	source, err := files.Open("geodata/" + name + ".gz")
	if err != nil {
		return err
	}
	defer source.Close()
	reader, err := gzip.NewReader(source)
	if err != nil {
		return err
	}
	defer reader.Close()
	staged, err := os.CreateTemp(filepath.Dir(target), ".geodata-*")
	if err != nil {
		return err
	}
	defer os.Remove(staged.Name())
	defer staged.Close()
	hash := sha256.New()
	written, err := io.Copy(io.MultiWriter(staged, hash), io.LimitReader(reader, size+1))
	if err != nil {
		return err
	}
	if written != size || hex.EncodeToString(hash.Sum(nil)) != digest {
		return fmt.Errorf("bundled geodata failed verification: %s", name)
	}
	if err := staged.Sync(); err != nil {
		return err
	}
	if err := staged.Close(); err != nil {
		return err
	}
	return os.Rename(staged.Name(), target)
}
