package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestPickerRealPopupReloadAndLatencyDistributions(t *testing.T) {
	fzf := os.Getenv("PI_TEST_FZF")
	if fzf == "" {
		var err error
		fzf, err = exec.LookPath("fzf")
		if err != nil {
			t.Skip("fzf unavailable")
		}
	}
	for _, program := range []string{"tmux", "python3", "fd", "go"} {
		if _, err := exec.LookPath(program); err != nil {
			t.Skip(program + " unavailable")
		}
	}
	root, err := os.MkdirTemp("/tmp", "picker-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(root)
	socket := filepath.Join(root, "server.sock")
	defer func() { _ = exec.Command("tmux", "-S", socket, "kill-server").Run() }()
	binary := filepath.Join(root, "tmux-project")
	if output, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, output)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "python3", "testdata/picker_ui.py", binary, fzf, root)
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("real popup: %v\n%s", err, output)
	}
	t.Logf("real private-popup timings (cold/warm XDG cache, uncontrolled OS cache): %s", output)
}
