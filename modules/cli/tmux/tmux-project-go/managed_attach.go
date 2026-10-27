package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type managedAttachRequest struct {
	ConversationID string `json:"conversationId"`
	LaunchID       string `json:"launchId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
}

// This is a terminal UI operation, not a JSON success receipt. It occupies the
// caller's controlling terminal until detach; it never creates a replacement.
func attachExactWindow(run exactTmux, request managedAttachRequest, terminal func(...string) (string, error)) error {
	target, err := inspectManagedFocusTarget(run, managedFocusRequest{ConversationID: request.ConversationID, LaunchID: request.LaunchID,
		SessionName: request.SessionName, WindowID: request.WindowID, PaneID: request.PaneID})
	if err != nil {
		return err
	}
	output, err := terminal("if-shell", "-F", "-t", target.Pane, target.Condition,
		"attach-session -t "+shellQuote(target.Target), "display-message -p managed-focus-stale")
	if err != nil {
		return err
	}
	if strings.TrimSpace(output) == "managed-focus-stale" {
		return fmt.Errorf("managed attach target changed before attachment")
	}
	return nil
}

type attachOutput struct {
	text     strings.Builder
	overflow bool
}

func (output *attachOutput) Write(data []byte) (int, error) {
	count := len(data)
	remaining := 65536 - output.text.Len()
	if count > remaining {
		data = data[:remaining]
		output.overflow = true
	}
	_, _ = output.text.Write(data)
	return count, nil // Drain excess output without allocating or blocking exit.
}

func managedTerminalCommand(args ...string) (string, error) {
	if !managedTerminalAvailable(os.Stdout) {
		return "", fmt.Errorf("managed attachment requires terminal stdout on Linux")
	}
	// Resolve the caller's real terminal device. Passing the /dev/tty alias
	// itself makes tmux advertise that alias to its server, which must reject it.
	tty, err := os.OpenFile("/dev/stdout", os.O_RDWR, 0)
	if err != nil {
		return "", fmt.Errorf("managed attachment requires terminal stdout: %w", err)
	}
	defer tty.Close()
	command := exec.Command("tmux", args...)
	var output attachOutput
	// tmux sends its UI directly to the terminal passed on stdin. Capturing its
	// small command stdout lets a guard refusal remain an actual error, rather
	// than mistaking display-message's zero exit status for a successful attach.
	command.Stdin = tty
	command.Stdout = &output
	command.Stderr = tty
	err = command.Run()
	if output.overflow {
		return "", fmt.Errorf("managed attachment command output exceeds bound")
	}
	return output.text.String(), err
}

func managedExactAttach() error {
	var request managedAttachRequest
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	return attachExactWindow(tmux, request, managedTerminalCommand)
}
