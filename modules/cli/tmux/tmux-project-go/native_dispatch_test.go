package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestRemovedManagedDispatch(t *testing.T) {
	if os.Getenv("PI_TEST_REMOVED_DISPATCH") == "1" {
		os.Args = []string{"tmux_project", "managed", "window-create-exact"}
		main()
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run=^TestRemovedManagedDispatch$")
	cmd.Env = []string{"PI_TEST_REMOVED_DISPATCH=1", "HOME=" + t.TempDir(), "PATH="}
	output, err := cmd.CombinedOutput()
	if exit, ok := err.(*exec.ExitError); !ok || exit.ExitCode() != 1 {
		t.Fatalf("removed dispatch did not fail closed: %v, %s", err, output)
	}
	if !strings.Contains(string(output), "tmux_project <native-window|") || strings.Contains(string(output), "<managed|") {
		t.Fatalf("removed managed runtime remains advertised: %s", output)
	}
}
