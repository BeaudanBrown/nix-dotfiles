package main

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestPickerPublicSocketFrameIdentityAndPermissions(t *testing.T) {
	for _, mode := range []string{"valid", "pending-open", "wrong-request", "oversized", "extra-frame", "invalid-utf8", "unsafe-socket", "lost-response"} {
		t.Run(mode, func(t *testing.T) {
			root, err := os.MkdirTemp("/tmp", "picker-host-")
			if err != nil {
				t.Fatal(err)
			}
			defer os.RemoveAll(root)
			path := filepath.Join(root, "control.sock")
			listener, err := net.Listen("unix", path)
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			if err := os.Chmod(path, 0600); err != nil {
				t.Fatal(err)
			}
			t.Setenv("PI_MANAGED_SESSIONS_RUNTIME_DIR", root)
			if mode == "unsafe-socket" {
				if err := os.Chmod(path, 0660); err != nil {
					t.Fatal(err)
				}
			}
			done := make(chan struct{})
			go func() {
				defer close(done)
				conn, err := listener.Accept()
				if err != nil {
					return
				}
				defer conn.Close()
				_ = conn.SetDeadline(time.Now().Add(time.Second))
				line, err := bufio.NewReader(conn).ReadBytes('\n')
				if err != nil {
					t.Error(err)
					return
				}
				var request struct {
					Version string                           `json:"version"`
					Actor   struct{ Kind, RequestID string } `json:"actor"`
					Action  map[string]any                   `json:"action"`
				}
				if err = json.Unmarshal(line, &request); err != nil {
					t.Error(err)
					return
				}
				if request.Version != "1.0.0" || request.Actor.Kind != "human_local" || !strings.HasPrefix(request.Actor.RequestID, "picker_") {
					t.Error("not public human-local wire")
				}
				if mode == "pending-open" && (request.Action["operation"] != "conversation.open" || request.Action["expectedGenerationId"] != "generation_"+strings.Repeat("a", 32)) {
					t.Error("lost open fence")
				}
				if mode == "lost-response" {
					return
				}
				id := request.Actor.RequestID
				if mode == "wrong-request" {
					id = "other"
				}
				data := map[string]any{"hostId": "fixture"}
				if mode == "pending-open" {
					data = map[string]any{"launchState": "window_created"}
				}
				response, _ := json.Marshal(map[string]any{"version": "1.0.0", "requestId": id, "ok": true, "data": data})
				response = append(response, '\n')
				switch mode {
				case "oversized":
					response = []byte(strings.Repeat("x", 65537))
				case "extra-frame":
					response = append(response, []byte("{}\n")...)
				case "invalid-utf8":
					response = []byte{0xff, '\n'}
				}
				_, _ = conn.Write(response)
			}()
			args := []string{"host", "status"}
			if mode == "pending-open" {
				args = []string{"conversation", "open", "conv_" + strings.Repeat("a", 32), "--expected-generation-id", "generation_" + strings.Repeat("a", 32)}
			}
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			var data map[string]any
			err = callPickerHost(ctx, args, &data)
			if mode == "valid" || mode == "pending-open" {
				if err != nil {
					t.Fatal(err)
				}
			} else if err == nil {
				t.Fatal("untrusted response/endpoint accepted")
			}
			listener.Close()
			<-done
		})
	}
	for _, args := range [][]string{{"conversation", "stop", "conv_" + strings.Repeat("a", 32)}, {"conversation", "list", "--limit", "101"}, {"conversation", "list", "--cursor"}} {
		if _, err := pickerHostAction(args); err == nil {
			t.Fatal("unsupported action", args)
		}
	}
}
