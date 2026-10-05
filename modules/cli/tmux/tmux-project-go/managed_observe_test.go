package main

import (
	"fmt"
	"strings"
	"testing"
)

func observationFixture() exactWindowProof {
	return exactWindowProof{"conv_" + strings.Repeat("a", 32), "123:456:" + strings.Repeat("c", 32), "launch_" + strings.Repeat("b", 32), "test", "@1", "%2", "789", "11111111-1111-1111-1111-111111111111", "1234"}
}
func observationLine(p exactWindowProof, dead string) string {
	return strings.Join([]string{strings.ReplaceAll(p.ServerID, ":", "|"), p.SessionName, p.WindowID, p.PaneID, p.PanePID, p.ConversationID, p.LaunchID, p.PaneID, p.PanePID, "1", "0", p.ProcessBootID, p.ProcessStartTicks, dead}, "|")
}
func TestExactObservationClassifications(t *testing.T) {
	p := observationFixture()
	header := strings.ReplaceAll(p.ServerID, ":", "|") + "\n"
	line := observationLine(p, "0")
	for _, tc := range []struct {
		name, inventory, process, want string
		unavailable                    bool
	}{
		{"live", header + line, "live", "running", false},
		{"dead retained with apparently live PID", header + observationLine(p, "1"), "live", "stopped", false},
		{"dead retained kernel unavailable", header + observationLine(p, "1"), "unknown", "stopped", false},
		{"invalid dead flag", header + observationLine(p, "2"), "live", "unknown", false},
		{"changed launch", header + strings.Replace(line, p.LaunchID, "launch_"+strings.Repeat("d", 32), 1), "live", "unknown", false},
		{"missing pane original live", header, "live", "unknown", false},
		{"missing pane original gone", header, "gone", "stopped", false},
		{"duplicate window", header + line + "\n" + line, "live", "unknown", false},
		{"duplicate conversation", header + line + "\n" + strings.Replace(line, "@1", "@2", 1), "live", "unknown", false},
		{"unavailable inventory", "", "live", "unknown", true},
		{"original gone during outage", "", "gone", "stopped", true},
		{"oversized inventory", strings.Repeat("x", 65537), "live", "unknown", false},
		{"malformed unrelated row", header + line + "\nbroken", "live", "unknown", false},
		{"different server", strings.Replace(header, "123|", "124|", 1) + line, "live", "unknown", false},
		{"unknown kernel state", header + line, "unknown", "unknown", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			calls := 0
			result, err := observeExactWindows(func(args ...string) (string, error) {
				calls++
				if strings.Join(args, " ") != "display-message -p #{pid}|#{start_time}|#{@managed_pi_server_id} ; list-panes -a -F "+exactProofFormat {
					t.Fatal("unexpected non-observation operation", args)
				}
				if tc.unavailable {
					return "", fmt.Errorf("offline")
				}
				return tc.inventory, nil
			}, []exactWindowProof{p}, func(exactWindowProof) string { return tc.process })
			if err != nil || calls != 1 || len(result) != 1 || result[0].State != tc.want || result[0].ConversationID != p.ConversationID || result[0].LaunchID != p.LaunchID {
				t.Fatalf("%#v %v calls=%d", result, err, calls)
			}
		})
	}
}
func TestExactObservationBoundsAndCost(t *testing.T) {
	p := observationFixture()
	var proofs []exactWindowProof
	inventory := strings.ReplaceAll(p.ServerID, ":", "|")
	for i := 0; i < 64; i++ {
		q := p
		q.ConversationID = fmt.Sprintf("conv_%032x", i)
		q.WindowID = fmt.Sprintf("@%d", i)
		q.PaneID = fmt.Sprintf("%%%d", i)
		proofs = append(proofs, q)
		inventory += "\n" + observationLine(q, "0")
	}
	calls, probes := 0, 0
	run := func(...string) (string, error) { calls++; return inventory, nil }
	process := func(exactWindowProof) string { probes++; return "live" }
	results, err := observeExactWindows(run, proofs, process)
	if err != nil || len(results) != 64 || calls != 1 || probes != 64 {
		t.Fatalf("one snapshot/64 probes: %d/%d, %v", calls, probes, err)
	}
	for _, r := range results {
		if r.State != "running" {
			t.Fatal(r)
		}
	}
	for _, bad := range [][]exactWindowProof{nil, append(proofs, p), {p, p}, {{ConversationID: "invalid"}}} {
		if _, err := observeExactWindows(run, bad, process); err == nil {
			t.Fatal("invalid request accepted")
		}
	}
	if calls != 1 || probes != 64 {
		t.Fatal("invalid requests performed observations")
	}
	legacy := p
	legacy.ProcessBootID = ""
	legacy.ProcessStartTicks = ""
	result, err := observeExactWindows(run, []exactWindowProof{legacy}, process)
	if err != nil || result[0].State != "unknown" || probes != 64 {
		t.Fatal("legacy proof was used as kernel evidence")
	}
}
func TestExactObservationRealKernelAndTmux(t *testing.T) {
	run := exactTestServer(t)
	p := exactTestWindow(t, run, "e")
	observe := func() string {
		t.Helper()
		result, err := observeExactWindows(run, []exactWindowProof{p}, observeExactProcess)
		if err != nil {
			t.Fatal(err)
		}
		return result[0].State
	}
	if got := observe(); got != "running" {
		t.Fatal(got)
	}
	if state, err := checkExactWindow(run, p); err != nil || state != "match" {
		t.Fatal("observation modified exact authority", state, err)
	}
	if _, err := run("set-window-option", "-t", p.WindowID, "remain-on-exit", "on"); err != nil {
		t.Fatal(err)
	}
	if _, err := stopExactProcess(run, p); err != nil {
		t.Fatal(err)
	}
	if got := observe(); got != "stopped" {
		t.Fatal(got)
	}
	// Check/terminate contracts are deliberately not broadened for presentation.
	if state, err := checkExactWindow(run, p); err != nil || state != "changed" {
		t.Fatal(state, err)
	}
}
