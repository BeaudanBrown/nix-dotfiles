package main

import (
	"os"
	"testing"
)

func TestTmuxMachineFormatsPreserveTabsInCLocale(t *testing.T) {
	t.Setenv("LC_ALL", "C")
	t.Setenv("LC_CTYPE", "C")
	t.Setenv("LANG", "C")
	t.Setenv("TMUX", "")
	if err := os.Unsetenv("TMUX"); err != nil {
		t.Fatal(err)
	}
	t.Setenv("TERM", "xterm-256color")
	run := exactTestServer(t)
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	// Exercise the real production transport, not an in-memory exactTmux stub.
	got, err := tmuxAt(socket, "display-message", "-p", "ascii\t#{session_name}\t✓")
	if err != nil || got != "ascii\texact\t✓" {
		t.Fatalf("machine format changed in C locale: %q, %v", got, err)
	}
}
