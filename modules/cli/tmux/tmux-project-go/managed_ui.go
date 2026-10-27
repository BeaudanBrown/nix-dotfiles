package main

import (
	"fmt"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

func supportedManagedUIVersion(version string) bool {
	version = strings.TrimSpace(version)
	if !strings.HasPrefix(version, "tmux ") {
		return false
	}
	parts := strings.SplitN(strings.TrimPrefix(version, "tmux "), ".", 2)
	if len(parts) != 2 {
		return false
	}
	major, err := strconv.Atoi(parts[0])
	if err != nil {
		return false
	}
	minorText := strings.TrimRight(parts[1], "abcdefghijklmnopqrstuvwxyz")
	minor, err := strconv.Atoi(minorText)
	return err == nil && (major > 3 || (major == 3 && minor >= 6))
}

// No server contact or creation: reject an incompatible UI before host admission.
func managedUICapabilities() error {
	version, err := exec.Command("tmux", "-V").Output()
	if err != nil || !supportedManagedUIVersion(string(version)) || runtime.GOOS != "linux" {
		return fmt.Errorf("managed terminal UI requires Linux and tmux 3.6 or newer")
	}
	return writeManagedResult(struct {
		Version       int  `json:"version"`
		ClientCapture bool `json:"clientCapture"`
		ExactFocus    bool `json:"exactFocus"`
		ExactAttach   bool `json:"exactAttach"`
	}{1, true, true, true})
}
