package main

import (
	"fmt"
	"io"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Every server and client here uses its own temporary socket. No test touches
// the user's default/shared server or starts a production service.
func exactTestServer(t *testing.T) exactTmux {
	t.Helper()
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Fatal("disposable tmux fixture requires tmux", err)
	}
	socket := filepath.Join(t.TempDir(), "tmux.sock")
	run := func(args ...string) (string, error) {
		out, err := exec.Command("tmux", append([]string{"-u", "-f", "/dev/null", "-S", socket}, args...)...).CombinedOutput()
		if err != nil {
			return "", fmt.Errorf("tmux: %w: %s", err, out)
		}
		return strings.TrimSpace(string(out)), nil
	}
	if _, err := run("new-session", "-d", "-s", "exact", "-n", "keep", "sleep 120"); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = run("kill-server") })
	return run
}
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
	cmd.Stdout, cmd.Stderr = io.Discard, io.Discard
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
