package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

const agentSocket = "/var/run/iping/agent.sock"

func forwardAgent(ctx context.Context, socket, method string, input io.Reader, output io.Writer) error {
	transport := &http.Transport{DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "unix", socket)
	}}
	defer transport.CloseIdleConnections()
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://iping/"+method, io.LimitReader(input, 512*1024+1))
	if err != nil {
		return failure("invalid_request")
	}
	response, err := (&http.Client{Transport: transport}).Do(request)
	if err != nil {
		return failure("agent_unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return failure("agent_unavailable")
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, 16*1024*1024+1))
	if err != nil || len(data) > 16*1024*1024 {
		return failure("invalid_response")
	}
	if _, err := output.Write(data); err != nil {
		return err
	}
	return nil
}

func (a *app) handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		method := r.URL.Path[1:]
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		if _, exists := methods[method]; !exists {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		var args arguments
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 512*1024))
		if decoder.Decode(&args) != nil {
			json.NewEncoder(w).Encode(envelope(nil, failure("invalid_request")))
			return
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			json.NewEncoder(w).Encode(envelope(nil, failure("invalid_request")))
			return
		}
		result, err := a.call(r.Context(), method, args)
		json.NewEncoder(w).Encode(envelope(result, err))
	})
}

func envelope(result any, err error) map[string]any {
	response := map[string]any{"ok": err == nil}
	if err != nil {
		var public failure
		if !errors.As(err, &public) {
			public = failure("storage_error")
		}
		response["error"] = public.Error()
	} else if result != nil {
		response["data"] = result
	}
	return response
}

func serveAgent() error {
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	a, err := newApp()
	if err != nil {
		return err
	}
	a.ctx = ctx
	daemonLock, err := os.OpenFile(filepath.Join(a.runDir, "agent.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer daemonLock.Close()
	if syscall.Flock(int(daemonLock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB) != nil {
		return failure("busy")
	}
	a.core = &coreRuntime{app: a}
	address, err := a.webAddress(ctx)
	if err != nil {
		return err
	}
	webListener, err := net.Listen("tcp", address)
	if err != nil {
		return err
	}
	defer webListener.Close()
	socket := filepath.Join(a.runDir, "agent.sock")
	if err := os.Remove(socket); err != nil && !os.IsNotExist(err) {
		return err
	}
	listener, err := net.Listen("unix", socket)
	if err != nil {
		return err
	}
	defer listener.Close()
	if err := os.Chmod(socket, 0600); err != nil {
		return err
	}
	server := &http.Server{Handler: a.handler(), ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: 20 * time.Second, IdleTimeout: 30 * time.Second}
	web := a.webHandler()
	webServer := &http.Server{Handler: web, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 30 * time.Second}
	stopped := make(chan error, 2)
	go func() { stopped <- server.Serve(listener) }()
	go func() { stopped <- webServer.Serve(webListener) }()
	if a.enabled(ctx) {
		if lock, err := a.lock(); err == nil {
			_, _ = a.startJob("connect", lock)
			lock.Close()
		}
	}
	select {
	case <-ctx.Done():
	case err := <-stopped:
		if err != http.ErrServerClosed {
			cancel()
		}
	}
	cancel()
	err = a.core.close()
	shutdown, done := context.WithTimeout(context.Background(), 5*time.Second)
	defer done()
	_ = server.Shutdown(shutdown)
	_ = webServer.Shutdown(shutdown)
	a.jobs.Wait()
	return err
}
