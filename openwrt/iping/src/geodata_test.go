package main

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"
)

func geoSnapshot(t *testing.T, version string) fstest.MapFS {
	t.Helper()
	files := fstest.MapFS{}
	metadata := map[string]any{}
	for name := range geoFilenames {
		data := []byte(name + "-" + version)
		digest := sha256.Sum256(data)
		metadata[name] = map[string]any{"sha256": hex.EncodeToString(digest[:]), "size": len(data)}
		var compressed bytes.Buffer
		writer := gzip.NewWriter(&compressed)
		if _, err := writer.Write(data); err != nil {
			t.Fatal(err)
		}
		if err := writer.Close(); err != nil {
			t.Fatal(err)
		}
		files["geodata/"+name+".gz"] = &fstest.MapFile{Data: compressed.Bytes()}
	}
	manifest, _ := json.Marshal(map[string]any{"files": metadata})
	files["geodata/manifest.json"] = &fstest.MapFile{Data: manifest}
	return files
}

func TestBundledGeodataInstallationAndUpgrade(t *testing.T) {
	home := t.TempDir()
	target := filepath.Join(home, "geoip.metadb")
	os.WriteFile(target, []byte("damaged download"), 0600)
	first := geoSnapshot(t, "first")
	if err := installBundledGeodata(first, home); err != nil {
		t.Fatal(err)
	}
	for name, filename := range geoFilenames {
		data, err := os.ReadFile(filepath.Join(home, filename))
		if err != nil || string(data) != name+"-first" {
			t.Fatalf("database %s was not installed: %v", name, err)
		}
	}
	os.WriteFile(target, []byte("online update"), 0600)
	if err := installBundledGeodata(first, home); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(target); string(data) != "online update" {
		t.Fatal("a restart replaced an online update")
	}
	next := geoSnapshot(t, "next")
	if err := installBundledGeodata(next, home); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(target); string(data) != "GEOIP.metadb-next" {
		t.Fatal("the next package did not replace the previous database")
	}
	os.Remove(target)
	if err := installBundledGeodata(next, home); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(target); string(data) != "GEOIP.metadb-next" {
		t.Fatal("a missing database was not restored")
	}
}

func TestDamagedBundledGeodataPreservesInstalledFile(t *testing.T) {
	home := t.TempDir()
	if err := installBundledGeodata(geoSnapshot(t, "first"), home); err != nil {
		t.Fatal(err)
	}
	next := geoSnapshot(t, "next")
	valid := next["geodata/GEOIP.metadb.gz"]
	next["geodata/GEOIP.metadb.gz"] = &fstest.MapFile{Data: valid.Data[:len(valid.Data)/2]}
	if err := installBundledGeodata(next, home); err == nil {
		t.Fatal("accepted incomplete bundled geodata")
	}
	target := filepath.Join(home, "geoip.metadb")
	if data, _ := os.ReadFile(target); string(data) != "GEOIP.metadb-first" {
		t.Fatal("an incomplete bundle replaced the installed database")
	}
	next["geodata/GEOIP.metadb.gz"] = valid
	if err := installBundledGeodata(next, home); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(target); string(data) != "GEOIP.metadb-next" {
		t.Fatal("the repaired bundle could not be retried")
	}
}
