package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

var apiCallPrefixes = map[string]bool{
	"tunnel":  true,
	"ipproxy": true,
	"user":    true,
	"pay":     true,
	"topup":   true,
	"system":  true,
}

// apiCall proxies the signed-in account's API so the Web UI can reuse the
// client models without storing the access key in the browser.
func (a *app) apiCall(ctx context.Context, args arguments) (any, error) {
	method := strings.ToUpper(strings.TrimSpace(args.Method))
	switch method {
	case http.MethodGet, http.MethodPost, http.MethodPatch, http.MethodDelete:
	default:
		return nil, failure("invalid_request")
	}
	path := strings.Trim(strings.TrimSpace(args.Path), "/")
	prefix, _, _ := strings.Cut(path, "/")
	if path == "" || !apiCallPrefixes[prefix] || strings.Contains(path, "..") ||
		strings.ContainsAny(path, "?#\\") {
		return nil, failure("invalid_request")
	}
	session, err := a.session()
	if err != nil {
		return nil, err
	}
	if session.AccessKey == "" {
		return nil, failure("not_logged_in")
	}
	endpoint, err := url.Parse(a.site + "/api/" + path)
	if err != nil {
		return nil, failure("invalid_request")
	}
	query := endpoint.Query()
	for key, value := range args.Params {
		switch typed := value.(type) {
		case string:
			query.Set(key, typed)
		case float64:
			query.Set(key, strconv.FormatFloat(typed, 'f', -1, 64))
		case bool:
			query.Set(key, strconv.FormatBool(typed))
		}
	}
	endpoint.RawQuery = query.Encode()
	var body io.Reader
	if args.Body != nil {
		data, err := json.Marshal(args.Body)
		if err != nil {
			return nil, failure("invalid_request")
		}
		body = bytes.NewReader(data)
	}
	request, err := http.NewRequestWithContext(ctx, method, endpoint.String(), body)
	if err != nil {
		return nil, failure("invalid_request")
	}
	request.Header.Set("Authorization", "Bearer "+session.AccessKey)
	request.Header.Set("Accept", "application/json")
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response, err := a.client.Do(request)
	if err != nil {
		return nil, failure("network_error")
	}
	defer response.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(response.Body, 4<<20))
	if err != nil {
		return nil, failure("invalid_response")
	}
	var decoded any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		decoded = string(raw)
	}
	return map[string]any{"status": response.StatusCode, "body": decoded}, nil
}
