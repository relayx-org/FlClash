package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"go.yaml.in/yaml/v3"
)

const mihomoBinary = "/usr/libexec/iping/mihomo"

type coreChild struct {
	cmd     *exec.Cmd
	started time.Time
	done    chan struct{}
	lease   *os.File
	ready   atomic.Bool
}

type coreRuntime struct {
	app     *app
	mu      sync.Mutex
	wanted  atomic.Bool
	closed  atomic.Bool
	working atomic.Int32
	current atomic.Pointer[coreChild]
}

func (r *coreRuntime) running() bool {
	child := r.current.Load()
	if child == nil || !child.ready.Load() {
		return false
	}
	select {
	case <-child.done:
		return false
	default:
		return true
	}
}

func (r *coreRuntime) setRunning(ctx context.Context, wanted bool) error {
	if r.closed.Load() {
		return failure("interrupted")
	}
	r.wanted.Store(wanted)
	r.working.Add(1)
	defer r.working.Add(-1)
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed.Load() {
		r.wanted.Store(false)
		return failure("interrupted")
	}
	return r.converge(ctx, false)
}

func (r *coreRuntime) restart(ctx context.Context) error {
	r.working.Add(1)
	defer r.working.Add(-1)
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.converge(ctx, true)
}

func (r *coreRuntime) converge(ctx context.Context, restart bool) error {
	child := r.current.Load()
	if child != nil && (restart || !r.wanted.Load() || !child.ready.Load()) {
		if err := r.stop(ctx); err != nil {
			return err
		}
	}
	if !r.closed.Load() && r.wanted.Load() && r.current.Load() == nil {
		return r.start(ctx)
	}
	return nil
}

func (r *coreRuntime) start(ctx context.Context) error {
	a := r.app
	if _, err := a.account(); err != nil {
		return err
	}
	data, err := os.ReadFile(a.profile)
	if err != nil {
		return failure("sync_required")
	}
	if err := a.validateProfile(ctx, data); err != nil {
		return err
	}
	lease, err := a.lockService(ctx, true)
	if err != nil {
		return err
	}
	release := true
	defer func() {
		if release {
			lease.Close()
		}
	}()
	if err := a.cleanNetwork(ctx); err != nil {
		return err
	}
	var config map[string]any
	if yaml.Unmarshal(data, &config) != nil {
		return failure("invalid_subscription")
	}
	if yamlSetting(config, "tun.enable") == true {
		device, _ := yamlSetting(config, "tun.device").(string)
		if err := a.acquireNetwork(ctx, device); err != nil {
			return err
		}
	}
	if err := writePrivate(a.runProfile, data); err != nil {
		return err
	}
	child := &coreChild{cmd: exec.Command(a.coreBinary, "-d", a.dataDir, "-f", a.runProfile), started: time.Now(), done: make(chan struct{}), lease: lease}
	child.cmd.Stdout = &coreLog{path: filepath.Join(a.runDir, "core.log")}
	child.cmd.Stderr = child.cmd.Stdout
	child.cmd.ExtraFiles = []*os.File{lease}
	configureChild(child.cmd)
	started := make(chan error, 1)
	go func() {
		// Linux ties Pdeathsig to the spawning thread, which must outlive the child.
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		err := child.cmd.Start()
		started <- err
		if err == nil {
			child.cmd.Wait()
		}
		child.ready.Store(false)
		close(child.done)
	}()
	if err := <-started; err != nil {
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if a.cleanNetwork(cleanup) != nil {
			return failure("service_failed")
		}
		return failure("service_failed")
	}
	release = false
	r.current.Store(child)
	go r.exited(child)
	deadline := time.NewTimer(12 * time.Second)
	defer deadline.Stop()
	for {
		if r.closed.Load() || !r.wanted.Load() || ctx.Err() != nil {
			if err := r.stop(context.Background()); err != nil {
				return err
			}
			return failure("interrupted")
		}
		probe, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
		err := a.controllerReady(probe)
		networkErr := a.networkReady(probe)
		cancel()
		if err == nil && networkErr == nil {
			select {
			case <-child.done:
				return failure("service_failed")
			default:
			}
			child.ready.Store(true)
			return nil
		}
		select {
		case <-child.done:
			if err := r.stop(context.Background()); err != nil {
				return err
			}
			return failure("service_failed")
		case <-deadline.C:
			if err := r.stop(context.Background()); err != nil {
				return err
			}
			return failure("service_failed")
		case <-time.After(100 * time.Millisecond):
		}
	}
}

func (r *coreRuntime) stop(ctx context.Context) error {
	child := r.current.Load()
	if child == nil {
		return nil
	}
	child.ready.Store(false)
	select {
	case <-child.done:
	default:
		_ = child.cmd.Process.Signal(syscall.SIGTERM)
		timer := time.NewTimer(8 * time.Second)
		select {
		case <-child.done:
		case <-ctx.Done():
		case <-timer.C:
		}
		timer.Stop()
		select {
		case <-child.done:
		default:
			_ = child.cmd.Process.Kill()
			select {
			case <-child.done:
			case <-time.After(3 * time.Second):
				return failure("service_failed")
			}
		}
	}
	cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := r.app.cleanNetwork(cleanup); err != nil {
		return err
	}
	if err := os.Remove(r.app.runProfile); err != nil && !os.IsNotExist(err) {
		return failure("storage_error")
	}
	child.lease.Close()
	r.current.Store(nil)
	return nil
}

func (r *coreRuntime) exited(child *coreChild) {
	<-child.done
	r.mu.Lock()
	if r.current.Load() != child {
		r.mu.Unlock()
		return
	}
	err := r.stop(context.Background())
	r.mu.Unlock()
	if err != nil || r.closed.Load() || !r.wanted.Load() {
		return
	}
	select {
	case <-r.app.ctx.Done():
		return
	case <-time.After(3 * time.Second):
	}
	ctx, cancel := context.WithTimeout(r.app.ctx, 60*time.Second)
	defer cancel()
	_ = r.restart(ctx)
}

func (r *coreRuntime) close() error {
	r.closed.Store(true)
	r.wanted.Store(false)
	r.mu.Lock()
	defer r.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	return r.stop(ctx)
}
