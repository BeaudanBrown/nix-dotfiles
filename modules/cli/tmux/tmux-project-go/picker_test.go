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

func pickerFixtureRow(letter string) pickerNativeSession {
	return pickerNativeSession{Version: 1, File: "/tmp/native-" + letter + ".jsonl", ID: "native-" + letter, Cwd: "/tmp", Title: "Same title"}
}
func pickerFixtureDecode(t *testing.T, data, target any) {
	t.Helper()
	encoded, err := json.Marshal(data)
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(encoded, target); err != nil {
		t.Fatal(err)
	}
}
func TestPickerNativeInventoryNeedsNoHostCapabilitiesOrRelay(t *testing.T) {
	good, bad := pickerFixtureRow("a"), pickerFixtureRow("b")
	bad.Version = 0
	calls := 0
	inventory, err := loadPickerInventory(context.Background(), func(_ context.Context, args []string, target any) error {
		calls++
		if !reflect.DeepEqual(args, []string{"list", "--all"}) {
			t.Fatalf("unexpected interface %v", args)
		}
		pickerFixtureDecode(t, []pickerNativeSession{good, bad, good}, target)
		return nil
	})
	if err != nil || calls != 1 || len(inventory.Rows) != 1 || inventory.Rows[0].ID != good.ID {
		t.Fatalf("native inventory: %+v %v %d", inventory, err, calls)
	}
}
func TestPickerDuplicateTitlesUseNativeFileIdentityWithoutGit(t *testing.T) {
	root := t.TempDir()
	a, b := pickerFixtureRow("a"), pickerFixtureRow("b")
	a.Cwd = root
	b.Cwd = root
	b.Running = true
	rows := buildPickerRows(context.Background(), nil, nil, []string{root}, pickerInventory{Rows: []pickerNativeSession{a, b}}, nil)
	if len(rows) != 3 {
		t.Fatalf("native and ordinary workspace rows lost: %+v", rows)
	}
	seen := map[string]bool{}
	for _, row := range rows {
		if seen[row.Key] {
			t.Fatal("duplicate identity")
		}
		seen[row.Key] = true
		if row.Native != nil && !strings.Contains(row.Candidate.Name, row.Native.ID) {
			t.Fatal("duplicate titles are not disambiguated")
		}
	}
	if !seen["path:"+root] || !seen[nativePickerKey(a.File)] || !seen[nativePickerKey(b.File)] {
		t.Fatal(seen)
	}
}
func TestPickerOrdinaryRowsSurviveMissingNativeMetadataAndArchivePresentation(t *testing.T) {
	root := t.TempDir()
	second := t.TempDir()
	sessions := []Session{{Name: "ordinary", Root: root, Role: roleRoot}}
	windows := []pickerWindow{{Session: "ordinary", Window: "@1", Pane: "%1"}}
	rows := buildPickerRows(context.Background(), sessions, windows, []string{root, second}, pickerInventory{}, nil)
	if len(rows) != 2 || rows[0].Native != nil || rows[1].Native != nil {
		t.Fatalf("offline workspace rows: %+v", rows)
	}
	archived := pickerFixtureRow("a")
	archived.Archived = true
	archived.Cwd = root
	rows = buildPickerRows(context.Background(), sessions, windows, []string{root, second}, pickerInventory{Rows: []pickerNativeSession{archived}}, nil)
	if len(rows) != 2 {
		t.Fatal("archive presentation affected ordinary workspaces", rows)
	}
	if _, err := os.Stat(filepath.Join(root, ".git")); !os.IsNotExist(err) {
		t.Fatal("fixture must have no Git metadata")
	}
}
func TestPickerLocalOpenFencesFileAndOnlyFocusesRequestingClient(t *testing.T) {
	run := exactTestServer(t)
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	client, pid := focusTestClient(t, run, "other")
	other, _ := focusTestClient(t, run, "other")
	before := focusClientRows(t, run)[other]
	pane, err := run("new-window", "-d", "-P", "-F", "#{pane_id}", "-t", "=exact", "sleep 120")
	if err != nil {
		t.Fatal(err)
	}
	server, _ := run("display-message", "-p", "#{pid}")
	row := pickerFixtureRow("a")
	calls := 0
	call := func(_ context.Context, args []string, target any) error {
		calls++
		if !reflect.DeepEqual(args, []string{"open", row.File, "--expected-id", row.ID}) {
			t.Fatal(args)
		}
		opened := row
		opened.Running = true
		opened.Pane = pane
		fmt.Sscan(server, &opened.ServerPID)
		pickerFixtureDecode(t, opened, target)
		return nil
	}
	if err := openPickerNative(context.Background(), call, row, client, pid, run); err != nil {
		t.Fatal(err)
	}
	states := focusClientRows(t, run)
	if !strings.HasPrefix(states[client], "exact|") || !strings.HasSuffix(states[client], "|"+pane) || states[other] != before {
		t.Fatal(states)
	}
	if calls != 1 {
		t.Fatal("unexpected retry", calls)
	}
	if err := openPickerNative(context.Background(), call, row, client, "1", run); err == nil || calls != 1 {
		t.Fatal("stale requester admitted")
	}
}
func TestPickerNativeWriterOutsideTmuxDoesNotTriggerAnotherOpen(t *testing.T) {
	run := exactTestServer(t)
	client, pid := focusTestClient(t, run, "exact")
	row := pickerFixtureRow("a")
	calls := 0
	err := openPickerNative(context.Background(), func(_ context.Context, _ []string, target any) error {
		calls++
		row.Running = true
		pickerFixtureDecode(t, row, target)
		return nil
	}, row, client, pid, run)
	if err == nil || !strings.Contains(err.Error(), "outside this tmux") || calls != 1 {
		t.Fatalf("%v %d", err, calls)
	}
}
func TestPickerDisplaySanitizesNativeTitles(t *testing.T) {
	row := pickerFixtureRow("a")
	row.Title = "unsafe\tlabel\n\x1b[31m"
	rows := buildPickerRows(context.Background(), nil, nil, nil, pickerInventory{Rows: []pickerNativeSession{row}}, nil)
	if len(rows) != 1 || strings.ContainsAny(rows[0].Candidate.Name, "\t\n\x1b") {
		t.Fatal(rows)
	}
}
