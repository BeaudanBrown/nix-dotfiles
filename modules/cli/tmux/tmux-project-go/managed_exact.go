package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"syscall"
)

const exactServerOption = "@managed_pi_server_id"
const exactLaunchOption = "@managed_pi_launch_id"
const exactPaneOption = "@managed_pi_pane_id"
const exactPIDOption = "@managed_pi_pane_pid"
const exactProofFormat = "#{pid}|#{start_time}|#{@managed_pi_server_id}|#{session_name}|#{window_id}|#{pane_id}|#{pane_pid}|#{@managed_pi_conversation_id}|#{@managed_pi_launch_id}|#{@managed_pi_pane_id}|#{@managed_pi_pane_pid}|#{window_panes}|#{window_linked}|#{@managed_pi_process_boot}|#{@managed_pi_process_start}|#{pane_dead}"

var exactLaunchPattern = regexp.MustCompile(`^launch_[a-f0-9]{32}$`)
var exactServerPattern = regexp.MustCompile(`^[1-9][0-9]{0,19}:[0-9]{1,20}:[a-f0-9]{32}$`)
var exactSessionPattern = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,128}$`)
var exactWindowPattern = regexp.MustCompile(`^@[0-9]{1,20}$`)
var exactPanePattern = regexp.MustCompile(`^%[0-9]{1,20}$`)
var exactPIDPattern = regexp.MustCompile(`^[1-9][0-9]{0,19}$`)
var exactStartPattern = regexp.MustCompile(`^[0-9]{1,20}$`)
var exactBootPattern = regexp.MustCompile(`^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$`)

type exactWindowProof struct {
	ConversationID    string `json:"conversationId"`
	ServerID          string `json:"serverId"`
	LaunchID          string `json:"launchId"`
	SessionName       string `json:"sessionName"`
	WindowID          string `json:"windowId"`
	PaneID            string `json:"paneId"`
	PanePID           string `json:"panePid"`
	ProcessBootID     string `json:"processBootId,omitempty"`
	ProcessStartTicks string `json:"processStartTicks,omitempty"`
}

type exactTmux func(...string) (string, error)

func requireExactProcessSupport() error {
	pid := fmt.Sprint(os.Getpid())
	handle, err := openProcessHandle(pid)
	if err != nil {
		return err
	}
	defer handle.close()
	boot, ticks, err := processBirth(pid)
	if err != nil {
		return err
	}
	return handle.verify(pid, boot, ticks)
}

func exactPID(value string) bool {
	pid, err := strconv.ParseUint(value, 10, 31)
	return err == nil && pid > 0 && exactPIDPattern.MatchString(value)
}

func validExactProof(p exactWindowProof) bool {
	return ((p.ProcessBootID == "" && p.ProcessStartTicks == "") || (exactBootPattern.MatchString(p.ProcessBootID) && exactStartPattern.MatchString(p.ProcessStartTicks))) && validConversationID(p.ConversationID) && exactServerPattern.MatchString(p.ServerID) && exactLaunchPattern.MatchString(p.LaunchID) &&
		exactSessionPattern.MatchString(p.SessionName) && exactWindowPattern.MatchString(p.WindowID) && exactPanePattern.MatchString(p.PaneID) && exactPIDPattern.MatchString(p.PanePID) && exactPID(p.PanePID) && exactPID(strings.Split(p.ServerID, ":")[0])
}

func parseExactProof(line string) (exactWindowProof, error) {
	fields := strings.Split(line, "|")
	if len(fields) != 16 {
		return exactWindowProof{}, fmt.Errorf("invalid exact window observation")
	}
	p := exactWindowProof{ServerID: strings.Join(fields[:3], ":"), SessionName: fields[3], WindowID: fields[4], PaneID: fields[5], PanePID: fields[6], ConversationID: fields[7], LaunchID: fields[8], ProcessBootID: fields[13], ProcessStartTicks: fields[14]}
	if !validExactProof(p) || fields[9] != p.PaneID || fields[10] != p.PanePID || fields[11] != "1" || fields[12] != "0" || fields[15] != "0" {
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
		if len(fields) != 16 {
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
		if proof.ProcessBootID != "" {
			handle, err := openProcessHandle(proof.PanePID)
			if err != nil {
				return nil, err
			}
			err = handle.verify(proof.PanePID, proof.ProcessBootID, proof.ProcessStartTicks)
			handle.close()
			if err != nil {
				return nil, err
			}
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
	handle, err := openProcessHandle(panePID)
	if err != nil {
		return exactWindowProof{}, err
	}
	defer handle.close()
	boot, ticks, err := processBirth(panePID)
	if err != nil {
		return exactWindowProof{}, err
	}
	if err := handle.verify(panePID, boot, ticks); err != nil {
		return exactWindowProof{}, err
	}
	token := make([]byte, 16)
	if _, err := rand.Read(token); err != nil {
		return exactWindowProof{}, err
	}
	condition := formatAnd(formatEqual("window_id", windowID), formatEqual("pane_id", paneID), formatEqual("pane_pid", panePID), formatEqual("window_panes", "1"), formatEqual("window_linked", "0"), "#{m:*pi-managed-"+launchID+"*,#{pane_start_command}}")
	// All commands stay in one server-side queue. No shell subprocess, sleep, or
	// second client connection occurs between the guard and its marker mutations.
	commands := "if-shell -F " + shellQuote(formatEqual(exactServerOption, "")) + " " + shellQuote("set-option -g "+exactServerOption+" "+hex.EncodeToString(token)) + " ; " +
		"set-option -w -t " + windowID + " " + managedWindowOption + " " + conversationID + " ; " +
		"set-option -w -t " + windowID + " " + exactLaunchOption + " " + launchID + " ; " +
		"set-option -w -t " + windowID + " " + exactPaneOption + " " + paneID + " ; " +
		"set-option -w -t " + windowID + " " + exactPIDOption + " " + panePID + " ; " +
		"set-option -w -t " + windowID + " @managed_pi_process_boot " + boot + " ; " +
		"set-option -w -t " + windowID + " @managed_pi_process_start " + ticks + " ; " +
		"display-message -p -t " + paneID + " " + shellQuote(exactProofFormat)
	output, err := run("if-shell", "-F", "-t", paneID, condition, commands, "display-message -p ownership-mismatch")
	if err != nil {
		return exactWindowProof{}, err
	}
	if err := handle.verify(panePID, boot, ticks); err != nil {
		return exactWindowProof{}, err
	}
	return parseExactProof(output)
}

// Read-only exact-resource observation. A changed marker is not absence, and a
// failed connection is only resolved as gone when the original server PID no
// longer exists. Signal zero observes existence; it sends no process signal.
func exactProcessGone(value string) bool {
	if !exactPID(value) {
		return false
	}
	pid, _ := strconv.Atoi(value)
	return errors.Is(syscall.Kill(pid, 0), syscall.ESRCH)
}
func checkExactWindow(run exactTmux, p exactWindowProof) (string, error) {
	if !validExactProof(p) {
		return "", fmt.Errorf("invalid exact window proof")
	}
	gone := func() (string, error) {
		if exactProcessGone(p.PanePID) {
			return "gone", nil
		}
		if p.ProcessBootID != "" {
			boot, ticks, err := processBirth(p.PanePID)
			if err == nil && (boot != p.ProcessBootID || ticks != p.ProcessStartTicks) {
				return "gone", nil
			}
		}
		return "", fmt.Errorf("original pane process exit cannot be verified")
	}
	output, err := run("display-message", "-p", "#{pid}|#{start_time}|#{@managed_pi_server_id}", ";", "list-panes", "-a", "-F", exactProofFormat)
	if err != nil {
		if exactProcessGone(strings.Split(p.ServerID, ":")[0]) {
			return gone()
		}
		return "", fmt.Errorf("original tmux server cannot be observed")
	}
	if len(output) > 65536 {
		return "", fmt.Errorf("managed window observation exceeds bound")
	}
	lines := strings.Split(output, "\n")
	server := strings.Split(lines[0], "|")
	expected := strings.Split(p.ServerID, ":")
	if len(server) != 3 || !exactPID(server[0]) || !exactStartPattern.MatchString(server[1]) {
		return "", fmt.Errorf("invalid server observation")
	}
	if server[0] != expected[0] || server[1] != expected[1] {
		return gone()
	}
	if server[2] != expected[2] {
		return "changed", nil
	}
	for _, line := range lines[1:] {
		if line == "" {
			continue
		}
		fields := strings.Split(line, "|")
		if len(fields) != 16 {
			return "", fmt.Errorf("managed window inventory is ambiguous")
		}
		if fields[4] != p.WindowID {
			continue
		}
		current, err := parseExactProof(line)
		if err != nil || current != p {
			return "changed", nil
		}
		if p.ProcessBootID != "" {
			handle, err := openProcessHandle(p.PanePID)
			if err != nil {
				return "", err
			}
			defer handle.close()
			if err := handle.verify(p.PanePID, p.ProcessBootID, p.ProcessStartTicks); err != nil {
				return "changed", nil
			}
		}
		return "match", nil
	}
	return gone()
}
func managedExactCheck() error {
	var proof exactWindowProof
	if err := readManagedRequest(&proof); err != nil {
		return err
	}
	state, err := checkExactWindow(tmux, proof)
	if err != nil {
		return err
	}
	return writeManagedResult(struct {
		State string `json:"state"`
	}{state})
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

// Pin the process before observing ownership and keep that exact descriptor
// through signalling. A pane/window replacement after the observation cannot
// redirect the signal. Never kill the tmux container: it may now hold other work.
func stopExactProcess(run exactTmux, proof exactWindowProof) (bool, error) {
	if !validExactProof(proof) || proof.ProcessBootID == "" {
		return false, fmt.Errorf("exact forced stop requires stable kernel process identity")
	}
	handle, err := openProcessHandle(proof.PanePID)
	if err != nil {
		return false, err
	}
	defer handle.close()
	if err := handle.verify(proof.PanePID, proof.ProcessBootID, proof.ProcessStartTicks); err != nil {
		return false, err
	}
	state, err := checkExactWindow(run, proof)
	if err != nil {
		return false, err
	}
	if state != "match" {
		return false, nil
	}
	if err := handle.verify(proof.PanePID, proof.ProcessBootID, proof.ProcessStartTicks); err != nil {
		return false, err
	}
	if err := handle.stop(); err != nil {
		return false, err
	}
	return true, nil
}

func managedExactTerminate() error {
	var proof exactWindowProof
	if err := readManagedRequest(&proof); err != nil {
		return err
	}
	if !validExactProof(proof) {
		return fmt.Errorf("invalid exact window proof")
	}
	terminated, err := stopExactProcess(tmux, proof)
	if err != nil {
		return err
	}
	return writeManagedResult(struct {
		Terminated bool `json:"terminated"`
	}{terminated})
}
