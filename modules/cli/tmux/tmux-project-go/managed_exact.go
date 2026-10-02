package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"
)

const exactServerOption = "@managed_pi_server_id"
const exactLaunchOption = "@managed_pi_launch_id"
const exactPaneOption = "@managed_pi_pane_id"
const exactPIDOption = "@managed_pi_pane_pid"
const exactProofFormat = "#{pid}|#{start_time}|#{@managed_pi_server_id}|#{session_name}|#{window_id}|#{pane_id}|#{pane_pid}|#{@managed_pi_conversation_id}|#{@managed_pi_launch_id}|#{@managed_pi_pane_id}|#{@managed_pi_pane_pid}|#{window_panes}"

var exactLaunchPattern = regexp.MustCompile(`^launch_[a-f0-9]{32}$`)
var exactServerPattern = regexp.MustCompile(`^[1-9][0-9]{0,19}:[0-9]{1,20}:[a-f0-9]{32}$`)
var exactSessionPattern = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,128}$`)
var exactWindowPattern = regexp.MustCompile(`^@[0-9]{1,20}$`)
var exactPanePattern = regexp.MustCompile(`^%[0-9]{1,20}$`)
var exactPIDPattern = regexp.MustCompile(`^[1-9][0-9]{0,19}$`)

type exactWindowProof struct {
	ConversationID string `json:"conversationId"`
	ServerID       string `json:"serverId"`
	LaunchID       string `json:"launchId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
	PanePID        string `json:"panePid"`
}

type exactTmux func(...string) (string, error)

func validExactProof(p exactWindowProof) bool {
	return validConversationID(p.ConversationID) && exactServerPattern.MatchString(p.ServerID) && exactLaunchPattern.MatchString(p.LaunchID) &&
		exactSessionPattern.MatchString(p.SessionName) && exactWindowPattern.MatchString(p.WindowID) && exactPanePattern.MatchString(p.PaneID) && exactPIDPattern.MatchString(p.PanePID)
}

func parseExactProof(line string) (exactWindowProof, error) {
	fields := strings.Split(line, "|")
	if len(fields) != 12 {
		return exactWindowProof{}, fmt.Errorf("invalid exact window observation")
	}
	p := exactWindowProof{ServerID: strings.Join(fields[:3], ":"), SessionName: fields[3], WindowID: fields[4], PaneID: fields[5], PanePID: fields[6], ConversationID: fields[7], LaunchID: fields[8]}
	if !validExactProof(p) || fields[9] != p.PaneID || fields[10] != p.PanePID || fields[11] != "1" {
		return exactWindowProof{}, fmt.Errorf("exact managed ownership is unavailable")
	}
	return p, nil
}

func inspectExactWindow(run exactTmux, conversationID string) (*exactWindowProof, error) {
	if !validConversationID(conversationID) {
		return nil, fmt.Errorf("invalid managed conversation identity")
	}
	output, err := run("list-panes", "-a", "-F", exactProofFormat)
	if err != nil {
		return nil, err
	} // Connection/permission failure is not proof of absence.
	if len(output) > 65536 {
		return nil, fmt.Errorf("managed window observation exceeds bound")
	}
	var found *exactWindowProof
	for _, line := range strings.Split(output, "\n") {
		if line == "" {
			continue
		}
		fields := strings.Split(line, "|")
		if len(fields) != 12 {
			return nil, fmt.Errorf("managed window inventory is ambiguous")
		}
		if fields[7] != conversationID {
			continue
		}
		if found != nil {
			return nil, fmt.Errorf("managed conversation has ambiguous ownership")
		}
		proof, err := parseExactProof(line)
		if err != nil {
			return nil, err
		}
		found = &proof
	}
	return found, nil
}

func formatAnd(parts ...string) string {
	result := "1"
	for _, part := range parts {
		result = "#{&&:" + result + "," + part + "}"
	}
	return result
}
func formatEqual(field, value string) string { return "#{==:#{" + field + "}," + value + "}" }

// The birth token is in pane_start_command from new-window itself. A later marker
// write must not adopt a reused target following a server restart or pane respawn.
func exactLaunchCommand(command, launchID string) (string, error) {
	if !exactLaunchPattern.MatchString(launchID) {
		return "", fmt.Errorf("invalid managed launch identity")
	}
	return ": pi-managed-" + launchID + "; " + command, nil
}

func markExactWindow(run exactTmux, windowID, paneID, panePID, conversationID, launchID string) (exactWindowProof, error) {
	if !exactWindowPattern.MatchString(windowID) || !exactPanePattern.MatchString(paneID) || !exactPIDPattern.MatchString(panePID) || !validConversationID(conversationID) || !exactLaunchPattern.MatchString(launchID) {
		return exactWindowProof{}, fmt.Errorf("invalid exact window creation identity")
	}
	token := make([]byte, 16)
	if _, err := rand.Read(token); err != nil {
		return exactWindowProof{}, err
	}
	condition := formatAnd(formatEqual("window_id", windowID), formatEqual("pane_id", paneID), formatEqual("pane_pid", panePID), formatEqual("window_panes", "1"), "#{m:*pi-managed-"+launchID+"*,#{pane_start_command}}")
	// All commands stay in one server-side queue. No shell subprocess, sleep, or
	// second client connection occurs between the guard and its marker mutations.
	commands := "if-shell -F " + shellQuote(formatEqual(exactServerOption, "")) + " " + shellQuote("set-option -g "+exactServerOption+" "+hex.EncodeToString(token)) + " ; " +
		"set-option -w -t " + windowID + " " + managedWindowOption + " " + conversationID + " ; " +
		"set-option -w -t " + windowID + " " + exactLaunchOption + " " + launchID + " ; " +
		"set-option -w -t " + windowID + " " + exactPaneOption + " " + paneID + " ; " +
		"set-option -w -t " + windowID + " " + exactPIDOption + " " + panePID + " ; " +
		"display-message -p -t " + paneID + " " + shellQuote(exactProofFormat)
	output, err := run("if-shell", "-F", "-t", paneID, condition, commands, "display-message -p ownership-mismatch")
	if err != nil {
		return exactWindowProof{}, err
	}
	return parseExactProof(output)
}

// A single -F condition and immediate command branch run in the same tmux server
// queue. Never split this into a Go-side check followed by a separate kill call.
func terminateExactWindow(run exactTmux, p exactWindowProof) (bool, error) {
	if !validExactProof(p) {
		return false, fmt.Errorf("invalid exact window proof")
	}
	server := strings.Split(p.ServerID, ":")
	condition := formatAnd(formatEqual("pid", server[0]), formatEqual("start_time", server[1]), formatEqual(exactServerOption, server[2]),
		formatEqual("session_name", p.SessionName), formatEqual("window_id", p.WindowID), formatEqual("pane_id", p.PaneID), formatEqual("pane_pid", p.PanePID),
		formatEqual(managedWindowOption, p.ConversationID), formatEqual(exactLaunchOption, p.LaunchID), formatEqual(exactPaneOption, p.PaneID), formatEqual(exactPIDOption, p.PanePID), formatEqual("window_panes", "1"))
	output, err := run("if-shell", "-F", "-t", p.PaneID, condition, "kill-window -t "+p.WindowID+" ; display-message -p terminated", "display-message -p ownership-mismatch")
	if err != nil {
		return false, err
	}
	if output == "terminated" {
		return true, nil
	}
	if output == "ownership-mismatch" {
		return false, nil
	}
	return false, fmt.Errorf("exact window termination outcome is unknown")
}

func managedExactInspect() error {
	var request struct {
		ConversationID string `json:"conversationId"`
	}
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	proof, err := inspectExactWindow(tmux, request.ConversationID)
	if err != nil {
		return err
	}
	return writeManagedResult(struct {
		ConversationID string            `json:"conversationId"`
		Exists         bool              `json:"exists"`
		Ownership      *exactWindowProof `json:"ownership,omitempty"`
	}{request.ConversationID, proof != nil, proof})
}
func managedExactTerminate() error {
	var proof exactWindowProof
	if err := readManagedRequest(&proof); err != nil {
		return err
	}
	terminated, err := terminateExactWindow(tmux, proof)
	if err != nil {
		return err
	}
	return writeManagedResult(struct {
		Terminated bool `json:"terminated"`
	}{terminated})
}
