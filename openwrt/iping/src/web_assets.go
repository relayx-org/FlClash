package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"io/fs"
	"mime"
	"net/http"
	"path"
	"strconv"
	"strings"
)

func acceptsGzip(value string) bool {
	wildcard := false
	for _, part := range strings.Split(value, ",") {
		fields := strings.Split(part, ";")
		coding := strings.TrimSpace(fields[0])
		quality := 1.0
		for _, parameter := range fields[1:] {
			key, value, _ := strings.Cut(strings.TrimSpace(parameter), "=")
			if key == "q" {
				parsed, err := strconv.ParseFloat(value, 64)
				if err != nil || parsed < 0 || parsed > 1 {
					quality = 0
				} else {
					quality = parsed
				}
			}
		}
		if strings.EqualFold(coding, "gzip") {
			return quality > 0
		}
		if coding == "*" {
			wildcard = quality > 0
		}
	}
	return wildcard
}

func webAssets(files fs.FS) http.Handler {
	etags := map[string]string{}
	manifest, _ := fs.ReadFile(files, "asset-etags.json")
	_ = json.Unmarshal(manifest, &etags)
	uiVersion, _ := fs.ReadFile(files, "ui-version")
	rendererVersion, _ := fs.ReadFile(files, "renderer-version")
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimPrefix(path.Clean(r.URL.Path), "/")
		immutable := false
		for _, prefix := range []string{
			"ui/" + string(uiVersion) + "/",
			"canvaskit/" + string(rendererVersion) + "/",
		} {
			if strings.HasPrefix(name, prefix) {
				name = strings.TrimPrefix(name, prefix)
				if strings.HasPrefix(prefix, "canvaskit/") {
					name = "canvaskit/" + name
				}
				immutable = true
				break
			}
		}
		if name == "" || name == "." {
			name = "index.html"
		}
		if name == "asset-etags.json" || strings.HasSuffix(name, ".gz") {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Cache-Control", "no-cache")
		if name != "index.html" && (immutable || (len(uiVersion) > 0 && r.URL.Query().Get("v") == string(uiVersion))) {
			w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		}
		w.Header().Set("Vary", "Accept-Encoding")
		source := name
		encoded := false
		if acceptsGzip(r.Header.Get("Accept-Encoding")) && r.Header.Get("Range") == "" {
			if _, err := fs.Stat(files, name+".gz"); err == nil {
				source = name + ".gz"
				encoded = true
			}
		}
		file, err := files.Open(source)
		if err != nil && !encoded {
			source = name + ".gz"
			file, err = files.Open(source)
		}
		if err != nil {
			if strings.HasPrefix(name, "fallback-fonts/") {
				http.Redirect(w, r, "https://fonts.gstatic.com/s/"+strings.TrimPrefix(name, "fallback-fonts/"), http.StatusFound)
				return
			}
			http.NotFound(w, r)
			return
		}
		defer file.Close()
		info, err := file.Stat()
		content, seekable := file.(io.ReadSeeker)
		if err != nil || info.IsDir() || !seekable {
			http.NotFound(w, r)
			return
		}
		etagName := name
		if encoded {
			w.Header().Set("Content-Encoding", "gzip")
			w.Header().Set("Content-Length", strconv.FormatInt(info.Size(), 10))
			etagName = source
		} else if source != name {
			reader, err := gzip.NewReader(file)
			if err != nil {
				http.Error(w, "Invalid asset", 500)
				return
			}
			data, err := io.ReadAll(reader)
			reader.Close()
			if err != nil {
				http.Error(w, "Invalid asset", 500)
				return
			}
			content = bytes.NewReader(data)
		}
		if contentType := mime.TypeByExtension(path.Ext(name)); contentType != "" {
			w.Header().Set("Content-Type", contentType)
		}
		if etag := etags[etagName]; etag != "" {
			w.Header().Set("ETag", `"`+etag+`"`)
		}
		http.ServeContent(w, r, name, info.ModTime(), content)
	})
}
