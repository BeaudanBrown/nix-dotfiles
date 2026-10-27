package main

import (
	"errors"
	"fmt"
	"os"
	"strings"
	"syscall"
)

const maxExactObservations = 64

type exactObservation struct {
	ConversationID string `json:"conversationId"`
	LaunchID       string `json:"launchId"`
	State          string `json:"state"`
}

// This is presentation evidence only. Never feed it into termination or adoption.
// pidfd signal zero in verify observes liveness; no terminating signal is sent.
func observeExactProcess(p exactWindowProof) string {
	if p.ProcessBootID == "" || p.ProcessStartTicks == "" {
		return "unknown"
	}
	handle, err := openProcessHandle(p.PanePID)
	if errors.Is(err, syscall.ESRCH) {
		return "gone"
	}
	if err != nil {
		return "unknown"
	}
	defer handle.close()
	boot, ticks, err := processBirth(p.PanePID)
	if errors.Is(err, os.ErrNotExist) {
		return "gone"
	}
	if err != nil {
		return "unknown"
	}
	if boot != p.ProcessBootID || ticks != p.ProcessStartTicks {
		return "gone"
	}
	if err = handle.verify(p.PanePID, boot, ticks); err != nil {
		if errors.Is(err, syscall.ESRCH) {
			return "gone"
		}
		return "unknown"
	}
	return "live"
}

func observeExactWindows(run exactTmux, proofs []exactWindowProof, process func(exactWindowProof) string) ([]exactObservation, error) {
	if len(proofs) < 1 || len(proofs) > maxExactObservations {
		return nil, fmt.Errorf("invalid exact observation batch size")
	}
	seen := make(map[string]bool)
	for _, p := range proofs {
		if !validExactProof(p) || seen[p.ConversationID] {
			return nil, fmt.Errorf("invalid or duplicate exact observation identity")
		}
		seen[p.ConversationID] = true
	}
	// One read-only inventory for the entire batch, not one scan per proof.
	output, inventoryErr := run("display-message", "-p", "#{pid}|#{start_time}|#{@managed_pi_server_id}", ";", "list-panes", "-a", "-F", exactProofFormat)
	serverID := ""
	windows := make(map[string][][]string)
	conversations := make(map[string]int)
	if inventoryErr == nil && len(output) <= 65536 {
		lines := strings.Split(output, "\n")
		serverID = strings.ReplaceAll(lines[0], "|", ":")
		if !exactServerPattern.MatchString(serverID) {
			inventoryErr = fmt.Errorf("invalid server observation")
		}
		for _, line := range lines[1:] {
			if line == "" {
				continue
			}
			fields := strings.Split(line, "|")
			if len(fields) != 16 {
				inventoryErr = fmt.Errorf("ambiguous inventory")
				break
			}
			windows[fields[4]] = append(windows[fields[4]], fields)
			conversations[fields[7]]++
		}
	} else {
		inventoryErr = fmt.Errorf("inventory unavailable")
	}
	result := make([]exactObservation, 0, len(proofs))
	for _, p := range proofs {
		state := "unknown"
		if p.ProcessBootID != "" && p.ProcessStartTicks != "" {
			processState := process(p)
			if processState == "gone" {
				state = "stopped"
			} else if inventoryErr == nil && serverID == p.ServerID {
				rows := windows[p.WindowID]
				if len(rows) == 1 && conversations[p.ConversationID] == 1 {
					fields := append([]string(nil), rows[0]...)
					dead := fields[15]
					// Parse every ownership field unchanged; only permit the known
					// dead-pane flag here. The existing exact parser stays strict.
					fields[15] = "0"
					current, err := parseExactProof(strings.Join(fields, "|"))
					if err == nil && current == p {
						if dead == "1" {
							state = "stopped"
						} else if dead == "0" && processState == "live" {
							state = "running"
						}
					}
				}
			}
		}
		result = append(result, exactObservation{p.ConversationID, p.LaunchID, state})
	}
	return result, nil
}

func managedExactObserve() error {
	var request struct {
		Proofs []exactWindowProof `json:"proofs"`
	}
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	observations, err := observeExactWindows(tmux, request.Proofs, observeExactProcess)
	if err != nil {
		return err
	}
	return writeManagedResult(map[string]any{"observations": observations})
}
