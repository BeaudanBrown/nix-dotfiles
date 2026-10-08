package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPickerPublicCLIAndDisposableTmuxRoundtrip(t *testing.T) {
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
	bin := t.TempDir()
	t.Setenv("PATH", bin+":"+os.Getenv("PATH"))
	log := filepath.Join(bin, "calls")
	row := pickerFixtureRow("a")
	row.ConversationID = proof.ConversationID
	envelope := func(data any) string {
		b, err := json.Marshal(map[string]any{"version": "1.0.0", "requestId": "fixture", "ok": true, "data": data})
		if err != nil {
			t.Fatal(err)
		}
		return shellQuote(string(b))
	}
	status := envelope(map[string]any{"hostId": "fixture", "capabilities": []string{"window-first-open-v1"}})
	list := envelope(map[string]any{"items": []pickerConversation{row}, "nextCursor": nil})
	opened := envelope(map[string]any{"conversationId": row.ConversationID, "launchId": proof.LaunchID, "launchState": "window_created", "window": map[string]any{"conversationId": row.ConversationID, "sessionName": proof.SessionName, "windowId": proof.WindowID, "paneId": proof.PaneID}})
	host := fmt.Sprintf("#!/bin/sh\nprintf '%%s\\n' \"$*\" >> %s\ncase \"$1 $2\" in\n'host status') printf '%%s\\n' %s;;\n'conversation list') printf '%%s\\n' %s;;\n'conversation open') printf '%%s\\n' %s; exit 8;;\n*) exit 3;;\nesac\n", shellQuote(log), status, list, opened)
	if err := os.WriteFile(filepath.Join(bin, "pi-managed-session"), []byte(host), 0700); err != nil {
		t.Fatal(err)
	}
	inventory, err := loadPickerInventory(context.Background(), callPickerHostCLI)
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
	if err := openPickerConversation(context.Background(), callPickerHostCLI, *rows[0].Conversation, client, pid, tmux); err != nil {
		t.Fatal(err)
	}
	if focusClientRows(t, run)[client] != "exact|"+proof.WindowID+"|"+proof.PaneID {
		t.Fatal("picker did not reach exact target")
	}
	calls, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(calls), "conversation open") != 1 || !strings.Contains(string(calls), "--expected-generation-id "+row.ActiveGenerationID) {
		t.Fatalf("bad public admission: %s", calls)
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
