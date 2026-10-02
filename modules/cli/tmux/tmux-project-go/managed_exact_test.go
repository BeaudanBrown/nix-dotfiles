package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func exactTestServer(t *testing.T) exactTmux {
	t.Helper()
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux unavailable")
	}
	socket := filepath.Join(t.TempDir(), "tmux.sock")
	run := func(args ...string) (string, error) {
		output, err := exec.Command("tmux", append([]string{"-f", "/dev/null", "-S", socket}, args...)...).CombinedOutput()
		if err != nil {
			return "", fmt.Errorf("tmux: %w: %s", err, output)
		}
		return strings.TrimSpace(string(output)), nil
	}
	if _, err := run("new-session", "-d", "-s", "exact", "-n", "keep", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = run("kill-server") })
	return run
}
func exactTestWindow(t *testing.T, run exactTmux, suffix string) exactWindowProof {
	t.Helper()
	conversationID := "conv_" + strings.Repeat(suffix, 32)
	launchID := "launch_" + strings.Repeat(suffix, 32)
	command, err := exactLaunchCommand("exec sleep 120", launchID)
	if err != nil {
		t.Fatal(err)
	}
	output, err := run("new-window", "-d", "-P", "-F", "#{window_id}|#{pane_id}|#{pane_pid}", "-t", "exact:", command)
	if err != nil {
		t.Fatal(err)
	}
	fields := strings.Split(output, "|")
	if len(fields) != 3 {
		t.Fatalf("bad creation: %q", output)
	}
	proof, err := markExactWindow(run, fields[0], fields[1], fields[2], conversationID, launchID)
	if err != nil {
		t.Fatal(err)
	}
	return proof
}

func TestExactWindowProofAndGuardedTermination(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	observed, err := inspectExactWindow(run, proof.ConversationID)
	if err != nil || observed == nil || *observed != proof {
		t.Fatalf("observation: %#v %v", observed, err)
	}
	for _, change := range []func(*exactWindowProof){
		func(p *exactWindowProof) { p.ServerID = "1:1:" + strings.Repeat("0", 32) },
		func(p *exactWindowProof) { p.LaunchID = "launch_" + strings.Repeat("b", 32) },
		func(p *exactWindowProof) { p.ConversationID = "conv_" + strings.Repeat("b", 32) },
		func(p *exactWindowProof) { p.PanePID = "1" },
		func(p *exactWindowProof) { p.SessionName = "other" },
	} {
		stale := proof
		change(&stale)
		stopped, err := terminateExactWindow(run, stale)
		if err != nil || stopped {
			t.Fatalf("stale proof stopped window: %v %v", stopped, err)
		}
	}
	stopped, err := terminateExactWindow(run, proof)
	if err != nil || !stopped {
		t.Fatalf("exact stop: %v %v", stopped, err)
	}
	if _, err := run("has-session", "-t", "exact"); err != nil {
		t.Fatal("unrelated window was removed", err)
	}
	observed, err = inspectExactWindow(run, proof.ConversationID)
	if err != nil || observed != nil {
		t.Fatalf("retired window remains: %#v %v", observed, err)
	}
}

func TestExactTerminationOfLastWindowReturnsAcknowledgement(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("kill-window", "-t", "exact:keep"); err != nil {
		t.Fatal(err)
	}
	stopped, err := terminateExactWindow(run, proof)
	if err != nil || !stopped {
		t.Fatalf("last-window termination: %v %v", stopped, err)
	}
}

func TestExactWindowRefusesRespawnAndAddedPanes(t *testing.T) {
	for _, mode := range []string{"respawn", "split"} {
		t.Run(mode, func(t *testing.T) {
			run := exactTestServer(t)
			proof := exactTestWindow(t, run, "a")
			var err error
			if mode == "respawn" {
				_, err = run("respawn-pane", "-k", "-t", proof.PaneID, "sleep 120")
			} else {
				_, err = run("split-window", "-d", "-t", proof.PaneID, "sleep 120")
			}
			if err != nil {
				t.Fatal(err)
			}
			stopped, err := terminateExactWindow(run, proof)
			if err != nil || stopped {
				t.Fatalf("changed resource stopped: %v %v", stopped, err)
			}
			if _, err := inspectExactWindow(run, proof.ConversationID); err == nil {
				t.Fatal("changed ownership produced a proof")
			}
		})
	}
}

func TestExactWindowRestartIDReuseAndLegacyRefusal(t *testing.T) {
	run := exactTestServer(t)
	old := exactTestWindow(t, run, "a")
	if _, err := run("kill-server"); err != nil {
		t.Fatal(err)
	}
	// The old server may still be finishing socket unlink; use a separate explicit
	// new-server connection only after shutdown has been observed by wait-for exit.
	for attempt := 0; attempt < 100; attempt++ {
		if _, err := run("list-sessions"); err != nil {
			break
		}
	}
	if _, err := run("new-session", "-d", "-s", "exact", "-n", "keep", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	current := exactTestWindow(t, run, "a")
	if old.WindowID != current.WindowID || old.PaneID != current.PaneID {
		t.Fatalf("fixture did not reuse IDs: %#v %#v", old, current)
	}
	if old.ServerID == current.ServerID {
		t.Fatal("server identity reused")
	}
	stopped, err := terminateExactWindow(run, old)
	if err != nil || stopped {
		t.Fatalf("old server proof stopped replacement: %v %v", stopped, err)
	}
	if _, err := run("set-option", "-w", "-u", "-t", current.WindowID, exactLaunchOption); err != nil {
		t.Fatal(err)
	}
	if _, err := inspectExactWindow(run, current.ConversationID); err == nil {
		t.Fatal("legacy marker adopted as exact ownership")
	}
}

func TestManagedExactCreateDispatchReturnsOriginalOwnership(t *testing.T) {
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux unavailable")
	}
	root := t.TempDir()
	runtime := filepath.Join(root, "run")
	bin := filepath.Join(root, "bin")
	workspace := filepath.Join(root, "projects", "workspace")
	for _, directory := range []string{runtime, bin, workspace} {
		if err := os.MkdirAll(directory, 0700); err != nil {
			t.Fatal(err)
		}
	}
	for name, body := range map[string]string{"pi": "#!/usr/bin/env sh\nexec sleep 120\n", "direnv": "#!/usr/bin/env sh\nshift 2\nexec \"$@\"\n"} {
		if err := os.WriteFile(filepath.Join(bin, name), []byte(body), 0700); err != nil {
			t.Fatal(err)
		}
	}
	conversationID := "conv_" + strings.Repeat("c", 32)
	launchID := "launch_" + strings.Repeat("d", 32)
	for name, value := range map[string]string{"TMUX": "", "HOME": root, "XDG_CONFIG_HOME": root, "XDG_RUNTIME_DIR": runtime, "TMUX_TMPDIR": runtime,
		"PATH": bin + string(os.PathListSeparator) + os.Getenv("PATH"), "PI_MANAGED_SESSIONS_WORKSPACE_ROOTS": `{"projects":"` + filepath.Join(root, "projects") + `"}`,
		"PI_MANAGED_SESSION_CONVERSATION_ID": conversationID, "PI_MANAGED_SESSION_WORKSPACE_PATH": workspace, "PI_MANAGED_SESSION_LAUNCH_ROLE": "project",
		"PI_MANAGED_SESSIONS_SOCKET": filepath.Join(runtime, "relay.sock"), "PI_MANAGED_SESSION_CONCEPT": "Fixture", "PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID": "boundary",
		"PI_MANAGED_SESSION_ATTACHMENT_NONCE": strings.Repeat("e", 32), "PI_MANAGED_PROJECT_SESSION_FILE": filepath.Join(root, "session.jsonl"),
		"PI_MANAGED_SESSION_MODEL": "", "PI_MANAGED_SESSION_THINKING": ""} {
		t.Setenv(name, value)
	}
	t.Cleanup(func() { _, _ = tmux("kill-server") })
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
	if err := json.NewEncoder(request).Encode(map[string]any{"conversationId": conversationID, "launchId": launchID, "placement": workspacePlacement{RootKey: "projects", Workspace: "workspace", RelativeCwd: ""}}); err != nil {
		t.Fatal(err)
	}
	if _, err := request.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	stdin, stdout := os.Stdin, os.Stdout
	os.Stdin, os.Stdout = request, response
	defer func() { os.Stdin, os.Stdout = stdin, stdout }()
	if err := managed([]string{"window-create-exact"}); err != nil {
		t.Fatal(err)
	}
	if _, err := response.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	var result managedProjectWindowResult
	if err := json.NewDecoder(response).Decode(&result); err != nil {
		t.Fatal(err)
	}
	if result.Ownership == nil || result.Ownership.LaunchID != launchID || result.Ownership.ConversationID != conversationID || result.Ownership.WindowID != result.WindowID || result.Ownership.PaneID != result.PaneID {
		t.Fatalf("invalid ownership: %#v", result)
	}
	stopped, err := terminateExactWindow(tmux, *result.Ownership)
	if err != nil || !stopped {
		t.Fatalf("exact created window stop: %v %v", stopped, err)
	}
}

func TestExactMarkerDoesNotAdoptWrongBirthToken(t *testing.T) {
	run := exactTestServer(t)
	output, err := run("new-window", "-d", "-P", "-F", "#{window_id}|#{pane_id}|#{pane_pid}", "-t", "exact:", "sleep 120")
	if err != nil {
		t.Fatal(err)
	}
	fields := strings.Split(output, "|")
	if _, err := markExactWindow(run, fields[0], fields[1], fields[2], "conv_"+strings.Repeat("a", 32), "launch_"+strings.Repeat("a", 32)); err == nil {
		t.Fatal("foreign birth was adopted")
	}
}
