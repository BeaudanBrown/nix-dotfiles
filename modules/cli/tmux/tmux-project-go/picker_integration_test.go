package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"
)

func TestPickerPublicSocketAndDisposableTmuxRoundtrip(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	client, _ := focusTestClient(t, run, "other")
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	server, err := run("display-message", "-p", "#{pid}")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("TMUX", socket+","+server+",0")
	t.Setenv("HOME", t.TempDir())
	root, err := os.MkdirTemp("/tmp", "picker-roundtrip-")
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
	if err = os.Chmod(path, 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PI_MANAGED_SESSIONS_RUNTIME_DIR", root)
	row := pickerFixtureRow("a")
	row.ConversationID = proof.ConversationID
	admitted := make(chan map[string]any, 1)
	go func() {
		for n := 0; n < 3; n++ {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			line, err := bufio.NewReader(conn).ReadBytes('\n')
			if err != nil {
				conn.Close()
				return
			}
			var request struct {
				Actor  struct{ RequestID string }
				Action map[string]any
			}
			if json.Unmarshal(line, &request) != nil {
				conn.Close()
				return
			}
			var data any
			switch request.Action["operation"] {
			case "host.status":
				data = pickerFixtureStatus()
			case "conversation.list":
				data = map[string]any{"items": []pickerConversation{row}, "nextCursor": nil}
			case "conversation.open":
				admitted <- request.Action
				data = map[string]any{"conversationId": row.ConversationID, "launchId": proof.LaunchID, "launchState": "window_created", "window": map[string]any{"conversationId": row.ConversationID, "sessionName": proof.SessionName, "windowId": proof.WindowID, "paneId": proof.PaneID}}
			}
			_ = json.NewEncoder(conn).Encode(map[string]any{"version": "1.0.0", "requestId": request.Actor.RequestID, "ok": true, "data": data})
			conn.Close()
		}
	}()
	inventory, err := loadPickerInventory(context.Background(), callPickerHost)
	if err != nil {
		t.Fatal(err)
	}
	rows := buildPickerRows(context.Background(), nil, nil, nil, inventory, nil)
	if len(rows) != 1 || rows[0].Conversation == nil {
		t.Fatalf("unexpected rows: %+v", rows)
	}
	pid, err := capturePickerClient(client, tmux)
	if err != nil {
		t.Fatal(err)
	}
	if err := openPickerConversation(context.Background(), callPickerHost, *rows[0].Conversation, client, pid, tmux); err != nil {
		t.Fatal(err)
	}
	if focusClientRows(t, run)[client] != "exact|"+proof.WindowID+"|"+proof.PaneID {
		t.Fatal("picker did not reach exact target")
	}
	call := <-admitted
	if call["expectedGenerationId"] != row.ActiveGenerationID || call["conversationId"] != row.ConversationID {
		t.Fatalf("bad public admission: %+v", call)
	}
}

func TestPickerInterruptedOpenDoesNotCancelOrReplayAcceptedWork(t *testing.T) {
	run := exactTestServer(t)
	client, pid := focusTestClient(t, run, "exact")
	row := pickerFixtureRow("b")
	calls := 0
	var proof exactWindowProof
	call := func(context.Context, []string, any) error {
		calls++
		proof = exactTestWindow(t, run, "b")
		return fmt.Errorf("response lost after admission")
	}
	if err := openPickerConversation(context.Background(), call, row, client, pid, run); err == nil {
		t.Fatal("lost response claimed success")
	}
	if calls != 1 {
		t.Fatal("automatic replay")
	}
	if state, err := checkExactWindow(run, proof); err != nil || state != "match" {
		t.Fatalf("accepted work lost: %s %v", state, err)
	}
}
