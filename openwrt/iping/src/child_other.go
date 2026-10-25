//go:build !linux

package main

import "os/exec"

func configureChild(child *exec.Cmd) {}
