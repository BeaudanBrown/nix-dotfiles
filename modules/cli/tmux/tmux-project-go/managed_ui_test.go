package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"runtime"
	"testing"
)

func TestManagedUIVersionRequiresKnownFormatAndMinimumFeatures(t *testing.T) {
	for _, version := range []string{"tmux 3.6", "tmux 3.6a\n", "tmux 3.7", "tmux 4.0"} {
		if !supportedManagedUIVersion(version) {
			t.Fatalf("rejected %q", version)
		}
	}
	for _, version := range []string{"tmux 3.5a", "tmux next-3.6", "3.6", "tmux 3.6; echo unsafe", "tmux 2.99", "tmux 3.6\nunknown"} {
		if supportedManagedUIVersion(version) {
			t.Fatalf("accepted %q", version)
		}
	}
}

func TestManagedUICapabilitiesAreStrictAndDoNotStartAServer(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("Linux terminal attachment")
	}
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Fatal(err)
	}
	root := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", root)
	t.Setenv("TMUX_TMPDIR", root)
	t.Setenv("TMUX", "")
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
	for _, input := range []string{`{}`, `{"unknown":true}`, `{} {}`} {
		if err := request.Truncate(0); err != nil {
			t.Fatal(err)
		}
		if _, err := request.Seek(0, 0); err != nil {
			t.Fatal(err)
		}
		if _, err := request.WriteString(input); err != nil {
			t.Fatal(err)
		}
		if _, err := request.Seek(0, 0); err != nil {
			t.Fatal(err)
		}
		err := managed([]string{"ui-capabilities"})
		if (input == "{}") != (err == nil) {
			t.Fatalf("%s: %v", input, err)
		}
	}
	if _, err := response.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	var value struct {
		Version                                int
		ClientCapture, ExactFocus, ExactAttach bool
	}
	if err := json.NewDecoder(response).Decode(&value); err != nil {
		t.Fatal(err)
	}
	if value.Version != 1 || !value.ClientCapture || !value.ExactFocus || !value.ExactAttach {
		t.Fatalf("bad capabilities: %+v", value)
	}
	if entries, err := os.ReadDir(root); err != nil || len(entries) != 2 {
		t.Fatalf("runtime effects: %v, %v", entries, err)
	}
}
