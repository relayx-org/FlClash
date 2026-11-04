package main

import (
	"context"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"go.yaml.in/yaml/v3"
)

const resourceEntryLimit = 500

type managedResource struct {
	ID       string    `json:"id"`
	Category string    `json:"category"`
	Name     string    `json:"name"`
	Path     string    `json:"path"`
	Size     int64     `json:"size"`
	Modified time.Time `json:"modified"`
	Virtual  bool      `json:"virtual,omitempty"`
}

var managedGeoFiles = []string{
	"GeoIP.dat", "GeoSite.dat", "geoip.dat", "geosite.dat",
	"ASN.mmdb", "Country.mmdb", "country.mmdb",
	"GeoIP.metadb", "GeoSite.metadb", "geoip.metadb", "geosite.metadb",
}

var managedCacheFiles = []string{"cache.db", "cache.db-shm", "cache.db-wal"}

func managedRelativePath(path string) (string, bool) {
	path = filepath.Clean(path)
	if path == "." || filepath.IsAbs(path) || path == ".." ||
		strings.HasPrefix(path, ".."+string(filepath.Separator)) {
		return "", false
	}
	return filepath.ToSlash(path), true
}

func (a *app) managedFile(relative, category string) (managedResource, bool) {
	relative, ok := managedRelativePath(relative)
	if !ok {
		return managedResource{}, false
	}
	full := filepath.Join(a.dataDir, filepath.FromSlash(relative))
	info, err := os.Lstat(full)
	if err != nil || info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() {
		return managedResource{}, false
	}
	return managedResource{
		ID: category + "/" + relative, Category: category,
		Name: filepath.Base(relative), Path: relative,
		Size: info.Size(), Modified: info.ModTime().Truncate(time.Millisecond),
	}, true
}

func (a *app) walkManagedDirectory(root, category string) []managedResource {
	full := filepath.Join(a.dataDir, root)
	info, err := os.Lstat(full)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return nil
	}
	items := []managedResource{}
	_ = filepath.WalkDir(full, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.Type()&os.ModeSymlink != 0 {
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.IsDir() {
			return nil
		}
		if !entry.Type().IsRegular() || len(items) >= resourceEntryLimit {
			return nil
		}
		relative, err := filepath.Rel(a.dataDir, path)
		if err != nil {
			return nil
		}
		relative, ok := managedRelativePath(relative)
		if !ok {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return nil
		}
		items = append(items, managedResource{
			ID: category + "/" + relative, Category: category,
			Name: filepath.Base(relative), Path: relative,
			Size: info.Size(), Modified: info.ModTime().Truncate(time.Millisecond),
		})
		return nil
	})
	sort.Slice(items, func(i, j int) bool { return items[i].Path < items[j].Path })
	return items
}

func (a *app) managedScripts() []managedResource {
	values, err := a.profileSettings()
	if err != nil {
		return nil
	}
	scripts, err := resourceScripts(values["custom.scripts"])
	if err != nil {
		return nil
	}
	modified := time.Time{}
	if info, err := os.Stat(filepath.Join(a.dataDir, "settings.json")); err == nil {
		modified = info.ModTime().Truncate(time.Millisecond)
	}
	items := []managedResource{}
	for _, script := range scripts {
		items = append(items, managedResource{
			ID: "script/" + script.ID, Category: "script",
			Name: script.Label, Path: "settings.json",
			Size: int64(len(script.Content)), Modified: modified, Virtual: true,
		})
	}
	return items
}

func (a *app) managedResources() []managedResource {
	items := []managedResource{}
	for _, name := range managedGeoFiles {
		if item, ok := a.managedFile(name, "geo"); ok {
			items = append(items, item)
		}
	}
	items = append(items, a.walkManagedDirectory("rule-providers", "rule-provider")...)
	items = append(items, a.walkManagedDirectory("proxy-providers", "proxy-provider")...)
	for _, name := range managedCacheFiles {
		if item, ok := a.managedFile(name, "cache"); ok {
			items = append(items, item)
		}
	}
	items = append(items, a.managedScripts()...)
	return items
}

func (a *app) resources(ctx context.Context, args arguments) (any, error) {
	action := strings.TrimSpace(args.Action)
	if action != "" && action != "refresh" {
		return nil, failure("invalid_request")
	}
	result := map[string]any{"items": a.managedResources()}
	if action == "refresh" {
		updated, failures, err := a.refreshManagedResources(ctx)
		if err != nil {
			return nil, err
		}
		result["updated"] = updated
		result["failures"] = failures
		result["items"] = a.managedResources()
	}
	return result, nil
}

func (a *app) refreshManagedResources(ctx context.Context) (int, []string, error) {
	if !a.running(ctx) {
		return 0, nil, failure("controller_unavailable")
	}
	data, err := os.ReadFile(a.runProfile)
	if err != nil {
		return 0, nil, failure("controller_unavailable")
	}
	var config struct {
		RuleProviders  map[string]any `yaml:"rule-providers"`
		ProxyProviders map[string]any `yaml:"proxy-providers"`
	}
	if yaml.Unmarshal(data, &config) != nil {
		return 0, nil, failure("controller_unavailable")
	}
	updated := 0
	failures := []string{}
	refresh := func(prefix string, names map[string]any) {
		sorted := make([]string, 0, len(names))
		for name := range names {
			sorted = append(sorted, name)
		}
		sort.Strings(sorted)
		for _, name := range sorted {
			if _, err := a.controller(ctx, http.MethodPut, prefix+url.PathEscape(name), []byte{}); err != nil {
				failures = append(failures, name)
				continue
			}
			updated++
		}
	}
	refresh("/providers/rules/", config.RuleProviders)
	refresh("/providers/proxies/", config.ProxyProviders)
	for _, path := range []string{"/cache/dns/flush", "/cache/fakeip/flush"} {
		if _, err := a.controller(ctx, http.MethodPost, path, []byte{}); err != nil {
			failures = append(failures, path)
			continue
		}
		updated++
	}
	return updated, failures, nil
}
