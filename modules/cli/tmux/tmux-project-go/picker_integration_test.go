package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestPickerUsesLocalCLIWithoutAnyRelaySocket(t *testing.T) {
	root := t.TempDir()
	helper := filepath.Join(root, "pi-session")
	record := filepath.Join(root, "args")
	shell, err := exec.LookPath("sh")
	if err != nil {
		t.Fatal(err)
	}
	rows, _ := json.Marshal([]pickerNativeSession{pickerFixtureRow("a")})
	script := fmt.Sprintf("#!%s\nprintf '%%s\\n' \"$@\" > %s\nprintf '%%s\\n' %s\n", shell, shellQuote(record), shellQuote(string(rows)))
	if err = os.WriteFile(helper, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PI_NATIVE_SESSION_HELPER", helper)
	t.Setenv("XDG_RUNTIME_DIR", root)
	inventory, err := loadPickerInventory(context.Background(), callPickerNative)
	if err != nil || len(inventory.Rows) != 1 {
		t.Fatalf("%+v %v", inventory, err)
	}
	args, _ := os.ReadFile(record)
	if string(args) != "list\n--all\n" {
		t.Fatalf("%q", args)
	}
}
func TestPickerInterruptedLocalOpenDoesNotCancelOrReplay(t *testing.T) {
	run := exactTestServer(t)
	client, pid := focusTestClient(t, run, "exact")
	row := pickerFixtureRow("b")
	calls := 0
	pane := ""
	call := func(context.Context, []string, any) error {
		calls++
		var err error
		pane, err = run("new-window", "-d", "-P", "-F", "#{pane_id}", "-t", "=exact", "sleep 120")
		if err != nil {
			t.Fatal(err)
		}
		return fmt.Errorf("reply lost")
	}
	if err := openPickerNative(context.Background(), call, row, client, pid, run); err == nil {
		t.Fatal("lost reply claimed success")
	}
	dead, err := run("display-message", "-p", "-t", pane, "#{pane_dead}")
	if calls != 1 || err != nil || dead != "0" {
		t.Fatalf("accepted local process changed: %d %s %v", calls, dead, err)
	}
}
func TestNativeWindowUsesOrdinaryWorkspaceWithoutGitOrManagedProtocol(t *testing.T) {
	run := exactTestServer(t)
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("TMUX_PROJECT_SOCKET", socket)
	t.Setenv("TMUX", "")
	cwd := t.TempDir()
	executable, err := exec.LookPath("sleep")
	if err != nil {
		t.Fatal(err)
	}
	request, _ := json.Marshal(map[string]any{"cwd": cwd, "argv": []string{executable, "120"}})
	var output bytes.Buffer
	if err := nativeWindow(bytes.NewReader(request), &output); err != nil {
		t.Fatal(err)
	}
	var opened struct {
		Pane string `json:"pane"`
	}
	if err = json.Unmarshal(output.Bytes(), &opened); err != nil {
		t.Fatal(err)
	}
	// Window creation precedes the child's chdir/exec; observe the actual
	// process rather than treating a tmux creation reply as readiness.
	path := ""
	for deadline := time.Now().Add(2 * time.Second); time.Now().Before(deadline); {
		path, err = run("display-message", "-p", "-t", opened.Pane, "#{pane_current_path}")
		if err == nil && path == cwd {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if err != nil || path != cwd {
		t.Fatalf("%s %v", path, err)
	}
	before, _ := run("list-panes", "-a", "-F", "#{pane_id}")
	for _, bad := range []string{`{"cwd":"/tmp","argv":["relative"]}`, `{"cwd":"/tmp","argv":["/single-argument-shell-form"]}`, string(request) + ` {}`, strings.Repeat(" ", 65537)} {
		if err := nativeWindow(strings.NewReader(bad), &bytes.Buffer{}); err == nil {
			t.Fatal("invalid request accepted")
		}
	}
	after, _ := run("list-panes", "-a", "-F", "#{pane_id}")
	if before != after {
		t.Fatal("invalid request created a window")
	}
}

func TestNativeWindowPreservesLiteralArgvAndSemicolonPaths(t *testing.T) {
	run := exactTestServer(t)
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("TMUX_PROJECT_SOCKET", socket)
	t.Setenv("TMUX", "")
	cwd := filepath.Join(t.TempDir(), "directory;")
	if err := os.Mkdir(cwd, 0700); err != nil {
		t.Fatal(err)
	}
	program, captured := filepath.Join(cwd, "program with spaces"), filepath.Join(cwd, "captured")
	shell, err := exec.LookPath("sh")
	if err != nil {
		t.Fatal(err)
	}
	script := fmt.Sprintf("#!%s\nprintf '%%s\\n' \"$@\" > %s\nexec sleep 120\n", shell, shellQuote(captured))
	if err := os.WriteFile(program, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	argv := []string{program, ";", "literal;", "\\;", "inside;word", "literal '$()'"}
	request, _ := json.Marshal(map[string]any{"cwd": cwd, "argv": argv})
	if err := nativeWindow(bytes.NewReader(request), &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	var data []byte
	for deadline := time.Now().Add(2 * time.Second); time.Now().Before(deadline); {
		data, err = os.ReadFile(captured)
		if err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if err != nil || string(data) != strings.Join(argv[1:], "\n")+"\n" {
		t.Fatalf("literal argv changed: %q %v", data, err)
	}
}
