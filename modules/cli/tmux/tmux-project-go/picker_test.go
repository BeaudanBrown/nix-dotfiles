package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func pickerFixtureRow(letter string) pickerConversation {
	return pickerConversation{ConversationID: "conv_" + strings.Repeat(letter, 32), Kind: "project", Title: "Same title", ActiveGenerationID: "generation_" + strings.Repeat("a", 32), RuntimeState: "stopped", LaunchState: "none", SetupState: "ready", Capabilities: []string{"window-first-open-v1"}, CheckoutID: "checkout_" + strings.Repeat("b", 32), ProjectKey: "project_" + strings.Repeat("b", 32)}
}
func pickerFixtureDecode(t *testing.T, data, target any) {
	t.Helper()
	b, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(b, target); err != nil {
		t.Fatal(err)
	}
}
func TestPickerPublicInventoryBoundaries(t *testing.T) {
	for _, mode := range []string{"valid", "duplicate", "cursor-loop", "missing-cursor", "partial-outage", "invalid-state", "oversized"} {
		t.Run(mode, func(t *testing.T) {
			calls := 0
			row := pickerFixtureRow("a")
			call := func(ctx context.Context, args []string, dest any) error {
				if args[0] == "host" {
					pickerFixtureDecode(t, pickerFixtureStatus(), dest)
					return nil
				}
				calls++
				if mode == "partial-outage" && calls > 1 {
					return fmt.Errorf("offline")
				}
				data := map[string]any{"items": []pickerConversation{row}, "nextCursor": nil}
				switch mode {
				case "duplicate":
					data["items"] = []pickerConversation{row, row}
				case "cursor-loop":
					row.ConversationID = fmt.Sprintf("conv_%032x", calls)
					data["items"] = []pickerConversation{row}
					data["nextCursor"] = "same"
				case "missing-cursor":
					delete(data, "nextCursor")
				case "partial-outage":
					data["nextCursor"] = "next"
				case "invalid-state":
					row.RuntimeState = "retired"
					data["items"] = []pickerConversation{row}
				case "oversized":
					data["items"] = make([]pickerConversation, 101)
				}
				pickerFixtureDecode(t, data, dest)
				return nil
			}
			got, err := loadPickerInventory(context.Background(), call)
			if mode == "valid" {
				if err != nil || len(got.Rows) != 1 {
					t.Fatalf("%+v %v", got, err)
				}
			} else if err == nil || len(got.Rows) != 0 {
				t.Fatalf("partial/untrusted inventory escaped: %+v %v", got, err)
			}
		})
	}
}
func TestPickerFailedUnknownIsNotStoppedAndNamesExposeIdentity(t *testing.T) {
	a, b := pickerFixtureRow("a"), pickerFixtureRow("b")
	a.RuntimeState, a.LaunchState = "unknown", "failed"
	b.RuntimeState, b.LaunchState = "running", "attached"
	rows := buildPickerRows(context.Background(), nil, nil, nil, pickerInventory{HostID: "host", Rows: []pickerConversation{a, b}}, nil)
	if len(rows) != 2 {
		t.Fatalf("rows: %+v", rows)
	}
	for _, row := range rows {
		if !strings.Contains(row.Candidate.Name, row.Conversation.ConversationID) {
			t.Fatal("conversation identity missing from display")
		}
		if row.Conversation.ConversationID == a.ConversationID && (!strings.Contains(row.Candidate.Name, "launch failed; ownership unknown") || strings.Contains(row.Candidate.Name, "stopped")) {
			t.Fatal("failed launch is not proof of process exit")
		}
	}
}

func TestPickerDigestAndCheckoutIdentityDedup(t *testing.T) {
	if got := pickerCheckout("host", "project_"+strings.Repeat("a", 32), "/work/project"); got != "checkout_34ec3bf360e92b747b6668f5cdc39557" {
		t.Fatal(got)
	}
	first, second := t.TempDir(), t.TempDir()
	a, b := pickerFixtureRow("a"), pickerFixtureRow("b")
	a.CheckoutID = pickerCheckout("host", a.ProjectKey, first)
	b.CheckoutID = a.CheckoutID
	b.LaunchState = "window_created"
	coordinator := pickerFixtureRow("c")
	coordinator.Kind = "coordinator"
	coordinator.ProjectKey = ""
	coordinator.CheckoutID = ""
	coordinator.RuntimeState = "running"
	coordinator.LaunchState = "attached"
	sessions := []Session{{Name: "ordinary", Root: first, Role: roleRoot}}
	windows := []pickerWindow{{Session: "ordinary", Window: "@1", Pane: "%1"}, {Session: "ordinary", Window: "@2", Pane: "%2", Marker: a.ConversationID}}
	rows := buildPickerRows(context.Background(), sessions, windows, []string{first, first, second}, pickerInventory{HostID: "host", Rows: []pickerConversation{a, b, coordinator}}, map[string]float64{first: 10, second: 20})
	if len(rows) != 5 {
		t.Fatalf("rows: %+v", rows)
	}
	if rows[0].Candidate.Value != second {
		t.Fatal("mixed score order changed")
	}
	seen := map[string]bool{}
	for _, row := range rows {
		if seen[row.Key] {
			t.Fatal("duplicate identity")
		}
		seen[row.Key] = true
		if row.Candidate.Kind == "path" && row.Candidate.Value == first {
			t.Fatal("managed checkout raw duplicate")
		}
	}
	if !seen["session:ordinary"] || !seen["conversation:"+coordinator.ConversationID] {
		t.Fatal("ordinary/coordinator omitted")
	}
	// Relay outage removes managed rows, not ordinary navigation. A marked last
	// window cannot masquerade as an ordinary candidate.
	offline := buildPickerRows(context.Background(), sessions, windows, []string{first, second}, pickerInventory{}, nil)
	for _, row := range offline {
		if row.Conversation != nil || row.Ordinary != nil && row.Ordinary.Marker != "" {
			t.Fatal("offline managed selection")
		}
	}
	if len(offline) != 2 {
		t.Fatalf("ordinary navigation lost: %+v", offline)
	}
	onlyManaged := buildPickerRows(context.Background(), sessions, windows[1:], []string{first}, pickerInventory{}, nil)
	if len(onlyManaged) != 1 || onlyManaged[0].Candidate.Kind != "path" {
		t.Fatal("managed-only session exposed as ordinary")
	}
}
func TestPickerWindowFirstOpenUsesFenceAndExactRequester(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	client, pid := focusTestClient(t, run, "other")
	row := pickerFixtureRow("a")
	row.ConversationID = proof.ConversationID
	calls := 0
	call := func(ctx context.Context, args []string, dest any) error {
		calls++
		expected := []string{"conversation", "open", row.ConversationID, "--expected-generation-id", row.ActiveGenerationID}
		if !reflect.DeepEqual(args, expected) {
			t.Fatal(args)
		}
		pickerFixtureDecode(t, map[string]any{"conversationId": row.ConversationID, "launchId": proof.LaunchID, "launchState": "window_created", "window": map[string]any{"conversationId": row.ConversationID, "sessionName": proof.SessionName, "windowId": proof.WindowID, "paneId": proof.PaneID}}, dest)
		return nil
	}
	if _, err := run("move-window", "-s", proof.WindowID, "-t", "exact:8"); err != nil {
		t.Fatal(err)
	}
	if err := openPickerConversation(context.Background(), call, row, client, pid, run); err != nil {
		t.Fatal(err)
	}
	if calls != 1 || focusClientRows(t, run)[client] != "exact|"+proof.WindowID+"|"+proof.PaneID {
		t.Fatal("not exact window-first focus")
	}
	before := focusClientRows(t, run)
	unavailable := func(context.Context, []string, any) error { calls++; return fmt.Errorf("retired or offline") }
	if err := openPickerConversation(context.Background(), unavailable, row, client, pid, run); err == nil {
		t.Fatal("offline fallback")
	}
	if calls != 2 || !reflect.DeepEqual(before, focusClientRows(t, run)) {
		t.Fatal("uncertain open replayed or focused")
	}
}
func TestPickerOrdinaryFocusNeverSelectsManagedLastWindow(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "b")
	target, err := run("new-window", "-d", "-P", "-F", "#{window_id}\t#{pane_id}", "-t", "exact", "sleep 120")
	if err != nil {
		t.Fatal(err)
	}
	p := strings.Split(target, "\t")
	if len(p) != 2 {
		t.Fatalf("unexpected new-window identity: %q", target)
	}
	w := pickerWindow{Session: "exact", Window: p[0], Pane: p[1]}
	client, pid := focusTestClient(t, run, "exact")
	if err := focusPickerOrdinary(w, client, pid, run); err != nil {
		t.Fatal(err)
	}
	if focusClientRows(t, run)[client] != "exact|"+w.Window+"|"+w.Pane {
		t.Fatal("wrong ordinary window")
	}
	if _, err := run("set-option", "-w", "-t", w.Window, managedWindowOption, proof.ConversationID); err != nil {
		t.Fatal(err)
	}
	if err := focusPickerOrdinary(w, client, pid, run); err == nil {
		t.Fatal("marked replacement accepted")
	}
	if err := focusPickerOrdinary(w, client, "2147483647", run); err == nil {
		t.Fatal("replaced requester accepted")
	}
}
func pickerFixtureStatus() map[string]any {
	return map[string]any{"hostId": "host", "relayState": "ready", "accountState": "ready", "capabilities": []string{"window-first-open-v1"}}
}
func TestPickerMissingRuntimeNeverFallsBack(t *testing.T) {
	bin := t.TempDir()
	marker := filepath.Join(bin, "called")
	t.Setenv("PATH", bin)
	t.Setenv("PI_MANAGED_SESSIONS_RUNTIME_DIR", "")
	t.Setenv("XDG_RUNTIME_DIR", "")
	if err := os.WriteFile(filepath.Join(bin, "pi-managed-session"), []byte("#!/bin/sh\n: > "+shellQuote(marker)+"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	var data any
	if callPickerHost(context.Background(), []string{"host", "status"}, &data) == nil {
		t.Fatal("missing endpoint accepted")
	}
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatal("CLI fallback attempted")
	}
}
