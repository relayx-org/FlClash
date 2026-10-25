//go:build ios

package mobile

import "core"

func Prepare(home, cacheHome string, tunnel bool) error {
	return core.PrepareIOS(home, cacheHome, tunnel)
}
