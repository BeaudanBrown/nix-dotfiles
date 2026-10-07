package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func focusRequest(proof exactWindowProof, client, pid string) managedFocusRequest {
	return managedFocusRequest{proof.ConversationID, proof.LaunchID, proof.SessionName, proof.WindowID, proof.PaneID, client, pid}
}

// Control-mode clients need no real terminal and attach only to this test's
// private socket. Never attach to or restart the shared user server.
func focusTestClient(t *testing.T, run exactTmux, session string) (string, string) {
	t.Helper()
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("tmux", "-S", socket, "-C", "attach-session", "-t", "="+session)
	input, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()
	t.Cleanup(func() {
		_ = input.Close()
		select {
		case <-done:
		case <-time.After(2 * time.Second):
			_ = cmd.Process.Kill()
			<-done
		}
	})
	for deadline := time.Now().Add(3 * time.Second); time.Now().Before(deadline); {
		output, err := run("list-clients", "-F", "#{client_pid}|#{client_name}")
		if err != nil {
			t.Fatal(err)
		}
		for _, line := range strings.Split(output, "\n") {
			parts := strings.SplitN(line, "|", 2)
			if len(parts) == 2 && parts[0] == fmt.Sprint(cmd.Process.Pid) {
				return parts[1], parts[0]
			}
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("test client did not attach")
	return "", ""
}

func focusClientRows(t *testing.T, run exactTmux) map[string]string {
	t.Helper()
	output, err := run("list-clients", "-F", "#{client_name}|#{session_name}|#{window_id}|#{pane_id}")
	if err != nil {
		t.Fatal(err)
	}
	rows := map[string]string{}
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "|", 2)
		if len(parts) == 2 {
			rows[parts[0]] = parts[1]
		}
	}
	return rows
}

func TestExactFocusRechecksClientNameAndPIDAsAPair(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	_, firstPID := focusTestClient(t, run, "exact")
	second, _ := focusTestClient(t, run, "other")
	before := focusClientRows(t, run)
	observed := func(args ...string) (string, error) {
		if args[0] == "list-clients" {
			return second + "|" + firstPID, nil
		}
		return run(args...)
	}
	if err := focusExactWindow(observed, focusRequest(proof, second, firstPID)); err == nil {
		t.Fatal("PID presence substituted for the captured client pair")
	}
	if after := focusClientRows(t, run); !reflect.DeepEqual(before, after) {
		t.Fatalf("wrong client switched: %v -> %v", before, after)
	}
	for _, name := range []string{"#{client_name}", "client,name", "client}name"} {
		if validManagedClientName(name) {
			t.Fatalf("format syntax accepted: %q", name)
		}
	}
}

func TestExactFocusSelectsStableTargetForOnlyRequestingClient(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	first, firstPID := focusTestClient(t, run, "exact")
	second, _ := focusTestClient(t, run, "other")
	before := focusClientRows(t, run)
	windows, _ := run("list-windows", "-a", "-F", "#{window_id}")
	if _, err := run("move-window", "-s", proof.WindowID, "-t", "exact:7"); err != nil {
		t.Fatal(err)
	}
	if err := focusExactWindow(run, focusRequest(proof, first, firstPID)); err != nil {
		t.Fatal(err)
	}
	after := focusClientRows(t, run)
	if after[first] != "exact|"+proof.WindowID+"|"+proof.PaneID {
		t.Fatalf("wrong target: %v", after)
	}
	if after[second] != before[second] {
		t.Fatalf("unrelated client switched: %v -> %v", before, after)
	}
	remaining, _ := run("list-windows", "-a", "-F", "#{window_id}")
	if remaining != windows {
		t.Fatalf("focus created or removed windows: %s -> %s", windows, remaining)
	}
}

func TestExactFocusRefusesChangedTargetInServerQueue(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "b")
	client, pid := focusTestClient(t, run, "exact")
	before := focusClientRows(t, run)
	injected := false
	race := func(args ...string) (string, error) {
		if args[0] == "if-shell" {
			injected = true
			if _, err := run("set-option", "-w", "-t", proof.WindowID, exactLaunchOption, "launch_"+strings.Repeat("c", 32)); err != nil {
				return "", err
			}
		}
		return run(args...)
	}
	if err := focusExactWindow(race, focusRequest(proof, client, pid)); err == nil || !strings.Contains(err.Error(), "changed before switching") {
		t.Fatalf("late replacement was accepted: %v", err)
	}
	if !injected || !reflect.DeepEqual(before, focusClientRows(t, run)) {
		t.Fatal("stale focus switched a client")
	}
}

func TestExactFocusRefusesMissingClientAndStaleLaunchWithoutFallback(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "d")
	client, pid := focusTestClient(t, run, "exact")
	before := focusClientRows(t, run)
	for _, request := range []managedFocusRequest{
		focusRequest(proof, "not-attached", pid),
		focusRequest(proof, client, "1"),
		{proof.ConversationID, "launch_" + strings.Repeat("e", 32), proof.SessionName, proof.WindowID, proof.PaneID, client, pid},
		{proof.ConversationID, proof.LaunchID, proof.SessionName, "@999999", proof.PaneID, client, pid},
	} {
		if err := focusExactWindow(run, request); err == nil {
			t.Fatal("invalid focus accepted")
		}
	}
	if !reflect.DeepEqual(before, focusClientRows(t, run)) {
		t.Fatal("invalid focus switched a client")
	}
	if _, err := run("detach-client", "-t", client); err != nil {
		t.Fatal(err)
	}
	if err := focusExactWindow(run, focusRequest(proof, client, pid)); err == nil {
		t.Fatal("detached client accepted")
	}
}

func TestExactFocusRefusesClientDisconnectionAfterObservation(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	client, pid := focusTestClient(t, run, "exact")
	if _, err := run("new-session", "-d", "-s", "other", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	other, _ := focusTestClient(t, run, "other")
	before := focusClientRows(t, run)[other]
	race := func(args ...string) (string, error) {
		if args[0] == "if-shell" {
			if _, err := run("detach-client", "-t", client); err != nil {
				return "", err
			}
		}
		return run(args...)
	}
	if err := focusExactWindow(race, focusRequest(proof, client, pid)); err == nil {
		t.Fatal("disconnected client was accepted")
	}
	if focusClientRows(t, run)[other] != before {
		t.Fatal("fallback switched another client")
	}
}

func TestManagedExactFocusDispatchUsesStrictWireAndPinnedServer(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "f")
	client, pid := focusTestClient(t, run, "exact")
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	realTmux, err := exec.LookPath("tmux")
	if err != nil {
		t.Fatal(err)
	}
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "tmux"), []byte("#!/bin/sh\nexec "+shellQuote(realTmux)+" -S "+shellQuote(socket)+" \"$@\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", root)
	t.Setenv("TMUX", "")
	t.Setenv("XDG_RUNTIME_DIR", filepath.Dir(socket))
	t.Setenv("TMUX_TMPDIR", filepath.Dir(socket))
	request, err := os.CreateTemp(root, "request")
	if err != nil {
		t.Fatal(err)
	}
	defer request.Close()
	response, err := os.CreateTemp(root, "response")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Close()
	stdin, stdout := os.Stdin, os.Stdout
	os.Stdin, os.Stdout = request, response
	defer func() { os.Stdin, os.Stdout = stdin, stdout }()
	if err := json.NewEncoder(request).Encode(focusRequest(proof, client, pid)); err != nil {
		t.Fatal(err)
	}
	if _, err := request.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	if err := managed([]string{"window-focus-exact"}); err != nil {
		t.Fatal(err)
	}
	if _, err := response.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	var result map[string]bool
	if err := json.NewDecoder(response).Decode(&result); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(result, map[string]bool{"focused": true}) {
		t.Fatalf("bad focus response: %v", result)
	}
	if err := request.Truncate(0); err != nil {
		t.Fatal(err)
	}
	if _, err := request.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	if _, err := request.WriteString(`{"unexpected":true}`); err != nil {
		t.Fatal(err)
	}
	if _, err := request.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	if err := managed([]string{"window-focus-exact"}); err == nil {
		t.Fatal("unknown field accepted")
	}
	t.Setenv("TMUX", "untrusted-socket,1,0")
	if err := managed([]string{"window-focus-exact"}); err == nil || !strings.Contains(err.Error(), "inherit") {
		t.Fatalf("attached target was inherited: %v", err)
	}
}

func TestManagedWindowSelectionNeverCleansUpDefaultSession(t *testing.T) {
	root := t.TempDir()
	log := filepath.Join(root, "calls")
	if err := os.WriteFile(filepath.Join(root, "tmux"), []byte("#!/bin/sh\nprintf '%s\\n' \"$@\" >> "+shellQuote(log)+"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", root)
	if err := switchToManagedWindow("=project:@3.%4", "project", "client"); err != nil {
		t.Fatal(err)
	}
	calls, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if string(calls) != "switch-client\n-c\nclient\n-t\n=project:@3.%4\n" {
		t.Fatalf("unexpected cleanup or targeting: %s", calls)
	}
}

func TestExactFocusRejectsAmbiguousOrOversizedClientInventory(t *testing.T) {
	request := managedFocusRequest{"conv_" + strings.Repeat("a", 32), "launch_" + strings.Repeat("a", 32), "exact", "@1", "%1", "client", "1"}
	for _, clients := range []string{"client|1\nclient|1", strings.Repeat("x", 65537)} {
		if err := focusExactWindow(func(args ...string) (string, error) {
			if args[0] != "list-clients" {
				t.Fatal("invalid client inventory reached target observation")
			}
			return clients, nil
		}, request); err == nil {
			t.Fatal("ambiguous client inventory accepted")
		}
	}
}

func TestExactFocusRejectsImplicitClientBeforeTmux(t *testing.T) {
	for _, client := range []string{"", "bad\nclient", strings.Repeat("x", 257)} {
		request := managedFocusRequest{"conv_" + strings.Repeat("a", 32), "launch_" + strings.Repeat("a", 32), "exact", "@1", "%1", client, "1"}
		if err := focusExactWindow(func(...string) (string, error) { t.Fatal("invalid request reached tmux"); return "", nil }, request); err == nil {
			t.Fatal("invalid client accepted")
		}
	}
}
