//go:build ios

package core

import (
	t "core/tun"
	"encoding/json"
	"fmt"
	"os"
	"runtime/debug"
	"sync"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/listener/sing_tun"
)

type TunCallbacks interface {
	Protect(fd int) bool
	ResolveUid(protocol int, source, target string) int
	ResolvePackage(uid int) string
}

var (
	iosEventMu       sync.RWMutex
	iosEventListener func([]byte)
	iosTunMu         sync.Mutex
	iosTun           *sing_tun.Listener
	iosPrepareOnce   sync.Once
	iosPrepareError  error
	iosTunnel        bool
)

func PrepareIOS(home, cacheHome string, tunnel bool) error {
	iosPrepareOnce.Do(func() {
		iosTunnel = tunnel
		route.SetEmbedMode(true)
		if tunnel {
			debug.SetMemoryLimit(32 << 20)
			debug.SetGCPercent(50)
		}
		if err := os.MkdirAll(cacheHome, 0o700); err != nil {
			iosPrepareError = err
			return
		}
		// A long-lived lock in the App Group causes 0xdead10cc on iOS suspension.
		constant.SetHomeDir(cacheHome)
		if cachefile.Cache().DB == nil {
			iosPrepareError = fmt.Errorf("cannot open iOS Core cache at %s", cacheHome)
		}
		constant.SetHomeDir(home)
	})
	return iosPrepareError
}

func recoverIOSExport(name string) {
	if r := recover(); r != nil {
		logError("panic in %s: %v\n%s", name, r, stackTrace())
	}
}

func InvokeMethod(data string, reply func([]byte)) {
	defer recoverIOSExport("invokeMethod")
	call := &MethodCall{}
	if err := json.Unmarshal([]byte(data), call); err != nil {
		reply(encodeResponse(MethodResponse{Error: &MethodError{
			Code: "invalid_method_call", Message: err.Error(),
		}}))
		return
	}
	dispatchMethodCall(call, reply)
}

func QuickSetup(initJSON, setupJSON string, answer func(string)) {
	safeGo("quickSetup", func() {
		defer func() {
			if r := recover(); r != nil {
				answer(fmt.Sprintf("internal panic: %v", r))
			}
		}()
		var params InitParams
		if err := json.Unmarshal([]byte(initJSON), &params); err != nil {
			answer(err.Error())
			return
		}
		handleInitClash(&params)
		setup := defaultSetupParams()
		if err := json.Unmarshal([]byte(setupJSON), setup); err != nil {
			answer(err.Error())
			return
		}
		isRunning.Store(iosTunnel)
		if err := handleSetupConfig(setup); err != nil {
			answer(err.Error())
			return
		}
		answer("")
	})
}

func StartTun(_ TunCallbacks, fd int, stack, address, dns, options string) bool {
	defer recoverIOSExport("startTun")
	iosTunMu.Lock()
	defer iosTunMu.Unlock()
	if iosTun != nil {
		_ = iosTun.Close()
	}
	iosTun = t.Start(fd, stack, address, dns, options)
	return iosTun != nil
}

func StopTun() {
	defer recoverIOSExport("stopTun")
	iosTunMu.Lock()
	defer iosTunMu.Unlock()
	if iosTun != nil {
		_ = iosTun.Close()
		iosTun = nil
	}
	handleStopListener()
}

func SetEventListener(listener func([]byte)) {
	iosEventMu.Lock()
	defer iosEventMu.Unlock()
	iosEventListener = listener
	if listener == nil {
		stopRouteWatch()
	}
}

func hasEventListener() bool {
	iosEventMu.RLock()
	defer iosEventMu.RUnlock()
	return iosEventListener != nil
}

func deliverEvent(data []byte) {
	iosEventMu.RLock()
	defer iosEventMu.RUnlock()
	if iosEventListener != nil {
		iosEventListener(data)
	}
}

func StartListener()         { handleStartListener() }
func StopListener()          { handleStopListener() }
func ForceGC()               { safeGo("forceGC", handleForceGC) }
func ResetNetwork()          { safeGo("resetNetwork", handleResetNetwork) }
func UpdateDns(value string) {}

func GetTraffic(onlyProxy bool) string {
	data, _ := json.Marshal(handleGetTraffic(onlyProxy))
	return string(data)
}

func GetTotalTraffic(onlyProxy bool) string {
	data, _ := json.Marshal(handleGetTotalTraffic(onlyProxy))
	return string(data)
}
