package webui

import (
	"embed"
	"io/fs"
)

//go:embed all:dist
var content embed.FS

func Files() fs.FS {
	files, _ := fs.Sub(content, "dist")
	return files
}
