package main

import (
	"fmt"
	"strings"
)

// The frontend captures these from its original invocation before unsetting
// TMUX for the pinned managed-command transport. Never infer the most-recent
// client: multiple clients may share the invoking pane.
type managedClientRequest struct {
	PaneID          string `json:"paneId"`
	SourceServerPID string `json:"sourceServerPid"`
	ClientName      string `json:"clientName,omitempty"`
}

type managedClientIdentity struct {
	ClientName string `json:"clientName"`
	ClientPID  string `json:"clientPid"`
}

func captureManagedClient(run exactTmux, request managedClientRequest) (managedClientIdentity, error) {
	var result managedClientIdentity
	if !exactPanePattern.MatchString(request.PaneID) || !exactPID(request.SourceServerPID) ||
		len(request.ClientName) > 256 || strings.IndexFunc(request.ClientName, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 {
		return result, fmt.Errorf("requesting client requires the original server PID and pane identity")
	}
	rows, err := run("list-clients", "-F", "#{client_name}\t#{client_pid}\t#{pane_id}\t#{pid}")
	if err != nil {
		return result, err
	}
	if len(rows) > 65536 {
		return result, fmt.Errorf("requesting client inventory exceeds bound")
	}
	matches := 0
	for _, row := range strings.Split(rows, "\n") {
		if row == "" {
			continue
		}
		parts := strings.Split(row, "\t")
		if len(parts) != 4 || parts[0] == "" || len(parts[0]) > 256 ||
			strings.IndexFunc(parts[0], func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 ||
			!exactPID(parts[1]) || !exactPanePattern.MatchString(parts[2]) || !exactPID(parts[3]) {
			return result, fmt.Errorf("requesting client inventory is malformed")
		}
		if parts[2] != request.PaneID || parts[3] != request.SourceServerPID ||
			(request.ClientName != "" && parts[0] != request.ClientName) {
			continue
		}
		result = managedClientIdentity{parts[0], parts[1]}
		matches++
	}
	if matches != 1 {
		return managedClientIdentity{}, fmt.Errorf("requesting client is unavailable or ambiguous; supply an exact client instead of guessing")
	}
	return result, nil
}

func managedClientCapture() error {
	var request managedClientRequest
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	result, err := captureManagedClient(tmux, request)
	if err != nil {
		return err
	}
	return writeManagedResult(result)
}
