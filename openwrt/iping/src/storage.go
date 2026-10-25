package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

type credentials struct {
	ID                int64  `json:"id"`
	Email             string `json:"email"`
	SubscriptionToken string `json:"subscription_token"`
	AccessKey         string `json:"access_key"`
	Site              string `json:"site"`
}

type profileInfo struct {
	Nodes  int   `json:"nodes"`
	Synced int64 `json:"synced"`
}

type jobInfo struct {
	Action  string `json:"action"`
	Started int64  `json:"started"`
	Done    bool   `json:"done"`
	Error   string `json:"error,omitempty"`
}

func readJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, target)
}

func writeJSON(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return writePrivate(path, data)
}

func writePrivate(path string, data []byte) error {
	file, err := os.CreateTemp(filepath.Dir(path), ".iping-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err = file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err = file.Sync(); err != nil {
		file.Close()
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}

func (a *app) lock() (*os.File, error) {
	file, err := os.OpenFile(filepath.Join(a.runDir, "lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, failure("storage_error")
	}
	if err = syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		return nil, failure("busy")
	}
	return file, nil
}

func (a *app) account() (credentials, error) {
	var account credentials
	if err := readJSON(filepath.Join(a.dataDir, "session.json"), &account); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return account, failure("not_logged_in")
		}
		return account, failure("storage_error")
	}
	if account.Site != a.site || !validCredentials(account) {
		return account, failure("login_required")
	}
	return account, nil
}
