package main

import (
	"os"
	"sync"
)

type coreLog struct {
	mu   sync.Mutex
	path string
}

func (w *coreLog) Write(data []byte) (int, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if info, err := os.Stat(w.path); err == nil && info.Size()+int64(len(data)) > 256*1024 {
		if err := os.Rename(w.path, w.path+".1"); err != nil {
			return 0, err
		}
	}
	file, err := os.OpenFile(w.path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err != nil {
		return 0, err
	}
	defer file.Close()
	return file.Write(data)
}
