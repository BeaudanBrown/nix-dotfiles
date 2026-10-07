package main

import (
	"fmt"
	"strings"
)

// UI-only targeting after host window-first open. This grants no launch, stop,
// pane replacement or shared-session cleanup authority.
type managedFocusRequest struct {
	ConversationID string `json:"conversationId"`
	LaunchID       string `json:"launchId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
	ClientName     string `json:"clientName"`
	ClientPID      string `json:"clientPid"`
}

func focusExactWindow(run exactTmux, request managedFocusRequest) error {
	if !validConversationID(request.ConversationID) || !exactLaunchPattern.MatchString(request.LaunchID) ||
		!exactSessionPattern.MatchString(request.SessionName) || !exactWindowPattern.MatchString(request.WindowID) ||
		!exactPanePattern.MatchString(request.PaneID) || !exactPID(request.ClientPID) || request.ClientName == "" || len(request.ClientName) > 256 ||
		strings.IndexFunc(request.ClientName, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 {
		return fmt.Errorf("exact managed focus requires a valid target and explicit requesting client")
	}
	clients, err := run("list-clients", "-F", "#{client_name}|#{client_pid}")
	if err != nil {
		return err
	}
	if len(clients) > 65536 {
		return fmt.Errorf("requesting client inventory exceeds bound")
	}
	matches := 0
	for _, client := range strings.Split(clients, "\n") {
		if client == request.ClientName+"|"+request.ClientPID {
			matches++
		}
	}
	if matches != 1 {
		return fmt.Errorf("requesting client is unavailable or ambiguous")
	}
	target, err := inspectManagedFocusTarget(run, request)
	if err != nil {
		return err
	}
	condition := formatAnd(target.Condition, "#{m:*1*,#{L:"+formatAnd(formatEqual("client_pid", request.ClientPID), "#{!=:#{client_session},}")+"}}")
	// Guard the captured PID as well as the target. -c itself accepts a name,
	// not a PID; a terminal name may be reused after client disconnection.
	command := "switch-client -c " + shellQuote(request.ClientName) + " -t " + shellQuote(target.Target)
	output, err := run("if-shell", "-F", "-t", target.Pane, condition, command, "display-message -p managed-focus-stale")
	if err != nil {
		return err
	}
	if strings.TrimSpace(output) != "" {
		return fmt.Errorf("managed focus target changed before switching")
	}
	return nil
}

type managedFocusTarget struct{ Pane, Condition, Target string }

func inspectManagedFocusTarget(run exactTmux, request managedFocusRequest) (managedFocusTarget, error) {
	var result managedFocusTarget
	if !validConversationID(request.ConversationID) || !exactLaunchPattern.MatchString(request.LaunchID) ||
		!exactSessionPattern.MatchString(request.SessionName) || !exactWindowPattern.MatchString(request.WindowID) || !exactPanePattern.MatchString(request.PaneID) {
		return result, fmt.Errorf("invalid exact managed target")
	}
	proof, err := inspectExactWindow(run, request.ConversationID)
	if err != nil {
		return result, err
	}
	if proof == nil || proof.ProcessBootID == "" || proof.LaunchID != request.LaunchID || proof.SessionName != request.SessionName ||
		proof.WindowID != request.WindowID || proof.PaneID != request.PaneID {
		return result, fmt.Errorf("managed focus target changed; open the conversation again")
	}
	server := strings.Split(proof.ServerID, ":")
	condition := formatAnd(formatEqual("pid", server[0]), formatEqual("start_time", server[1]), formatEqual(exactServerOption, server[2]),
		formatEqual("session_name", proof.SessionName), formatEqual("window_id", proof.WindowID), formatEqual("pane_id", proof.PaneID),
		formatEqual("pane_pid", proof.PanePID), formatEqual(managedWindowOption, proof.ConversationID), formatEqual(exactLaunchOption, proof.LaunchID),
		formatEqual(exactPaneOption, proof.PaneID), formatEqual(exactPIDOption, proof.PanePID), formatEqual("window_panes", "1"),
		formatEqual("window_linked", "0"), formatEqual("pane_dead", "0"), formatEqual("@managed_pi_process_boot", proof.ProcessBootID),
		formatEqual("@managed_pi_process_start", proof.ProcessStartTicks))
	return managedFocusTarget{proof.PaneID, condition, "=" + proof.SessionName + ":" + proof.WindowID + "." + proof.PaneID}, nil
}

func managedExactFocus() error {
	var request managedFocusRequest
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	if err := focusExactWindow(tmux, request); err != nil {
		return err
	}
	return writeManagedResult(struct {
		Focused bool `json:"focused"`
	}{true})
}
