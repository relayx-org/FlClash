package main

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"sync"
	"time"
)

const requestLimit = 200

type requestEntry struct {
	ID          string   `json:"id"`
	Host        string   `json:"host"`
	Source      string   `json:"source"`
	Destination string   `json:"destination"`
	Network     string   `json:"network"`
	Type        string   `json:"type"`
	Rule        string   `json:"rule"`
	RulePayload string   `json:"rule_payload"`
	Chains      []string `json:"chains"`
	Upload      int64    `json:"upload"`
	Download    int64    `json:"download"`
	Start       string   `json:"start"`
	Duration    int64    `json:"duration"`
	Closed      bool     `json:"closed"`
}

type requestBuffer struct {
	mu      sync.Mutex
	records []requestEntry
	active  map[string]bool
}

func (a *app) requests(ctx context.Context) (any, error) {
	data, err := a.controller(ctx, http.MethodGet, "/connections", nil)
	if err != nil {
		return nil, err
	}
	var payload struct {
		Connections []struct {
			ID       string `json:"id"`
			Metadata struct {
				Network         string `json:"network"`
				Type            string `json:"type"`
				SourceIP        string `json:"sourceIP"`
				SourcePort      string `json:"sourcePort"`
				DestinationIP   string `json:"destinationIP"`
				DestinationPort string `json:"destinationPort"`
				Host            string `json:"host"`
				Rule            string `json:"rule"`
				RulePayload     string `json:"rulePayload"`
			} `json:"metadata"`
			Upload   int64    `json:"upload"`
			Download int64    `json:"download"`
			Start    string   `json:"start"`
			Chains   []string `json:"chains"`
		} `json:"connections"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		return nil, failure("invalid_response")
	}
	now := time.Now()
	a.requestMu.Lock()
	if a.requestActive == nil {
		a.requestActive = map[string]bool{}
	}
	seen := map[string]bool{}
	for _, item := range payload.Connections {
		seen[item.ID] = true
		host := item.Metadata.Host
		if host == "" {
			host = item.Metadata.DestinationIP
		}
		source := item.Metadata.SourceIP
		if item.Metadata.SourcePort != "" {
			source += ":" + item.Metadata.SourcePort
		}
		destination := item.Metadata.DestinationIP
		if item.Metadata.DestinationPort != "" {
			destination += ":" + item.Metadata.DestinationPort
		}
		start, _ := time.Parse(time.RFC3339Nano, item.Start)
		duration := int64(0)
		if !start.IsZero() {
			duration = int64(now.Sub(start).Seconds())
		}
		entry := requestEntry{
			ID: item.ID, Host: host, Source: source, Destination: destination,
			Network: item.Metadata.Network, Type: item.Metadata.Type,
			Rule: item.Metadata.Rule, RulePayload: item.Metadata.RulePayload,
			Chains: item.Chains, Upload: item.Upload, Download: item.Download,
			Start: item.Start, Duration: duration,
		}
		replaced := false
		for index := range a.requestLog {
			if a.requestLog[index].ID == item.ID {
				a.requestLog[index] = entry
				replaced = true
				break
			}
		}
		if !replaced {
			a.requestLog = append(a.requestLog, entry)
		}
	}
	for index := range a.requestLog {
		if !seen[a.requestLog[index].ID] {
			a.requestLog[index].Closed = true
		}
	}
	if len(a.requestLog) > requestLimit {
		a.requestLog = a.requestLog[len(a.requestLog)-requestLimit:]
	}
	a.requestActive = seen
	records := append([]requestEntry(nil), a.requestLog...)
	a.requestMu.Unlock()
	sort.SliceStable(records, func(i, j int) bool {
		return records[i].Start > records[j].Start
	})
	return records, nil
}
