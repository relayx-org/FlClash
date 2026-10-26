package core

import (
	"context"
	probe "github.com/relayx-org/FlClash/openwrt/iping/probe"
)

type ServiceCheckParams = probe.ServiceCheckParams
type ServiceCheckItem = probe.ServiceCheckItem

func handleServiceCheck(params *ServiceCheckParams) []ServiceCheckItem {
	return coreProbes.CheckServices(context.Background(), params)
}
