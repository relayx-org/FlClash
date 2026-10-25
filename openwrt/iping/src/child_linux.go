package main

import (
	"os/exec"
	"syscall"
)

func configureChild(child *exec.Cmd) {
	child.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}
}
