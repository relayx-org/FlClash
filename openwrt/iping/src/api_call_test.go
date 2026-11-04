package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestAPICallProxiesTheSignedInAccount(t *testing.T) {
	var gotAuth, gotQuery, gotBody string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotQuery = r.URL.Query().Get("status")
		data, _ := io.ReadAll(r.Body)
		gotBody = string(data)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"total":1}`))
	}))
	defer server.Close()

	app := &app{site: server.URL, client: server.Client(), dataDir: t.TempDir(), runDir: t.TempDir()}
	session, _ := json.Marshal(credentials{
		ID: 1, Email: "user@example.com", SubscriptionToken: "token",
		AccessKey: "11111111-1111-1111-1111-111111111111", Site: server.URL,
	})
	if err := os.WriteFile(filepath.Join(app.dataDir, "session.json"), session, 0600); err != nil {
		t.Fatal(err)
	}

	result, err := app.apiCall(context.Background(), arguments{
		Method: "POST", Path: "tunnel/list", Params: map[string]any{"status": "active"},
		Body: map[string]any{"page": 2},
	})
	if err != nil {
		t.Fatal(err)
	}
	if gotAuth != "Bearer 11111111-1111-1111-1111-111111111111" || gotQuery != "active" {
		t.Fatalf("unexpected request: auth=%q query=%q", gotAuth, gotQuery)
	}
	if gotBody != `{"page":2}` {
		t.Fatalf("unexpected body: %s", gotBody)
	}
	reply, ok := result.(map[string]any)
	if !ok || reply["status"] != http.StatusOK {
		t.Fatalf("unexpected reply: %#v", result)
	}
	if body, ok := reply["body"].(map[string]any); !ok || body["total"] != float64(1) {
		t.Fatalf("unexpected body: %#v", reply["body"])
	}
}

func TestAPICallRejectsUnlistedPaths(t *testing.T) {
	app := &app{}
	for _, path := range []string{"admin/users", "../secret", "", "tunnel\\list"} {
		if _, err := app.apiCall(context.Background(), arguments{Method: "GET", Path: path}); err == nil {
			t.Fatalf("expected %q to be rejected", path)
		}
	}
}
