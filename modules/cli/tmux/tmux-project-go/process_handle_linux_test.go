//go:build linux && (amd64 || arm64)

package main

import (
	"bufio"
	"fmt"
	"os/exec"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestPinnedStopEscalatesOnlyOnTheSameDescriptor(t *testing.T) {
	child := exec.Command("sh", "-c", "trap '' TERM; echo ready; exec sleep 120")
	output, err := child.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	defer child.Process.Kill()
	if line, err := bufio.NewReader(output).ReadString('\n'); err != nil || line != "ready\n" {
		t.Fatalf("child readiness: %q %v", line, err)
	}
	handle, err := openProcessHandle(fmt.Sprint(child.Process.Pid))
	if err != nil {
		t.Fatal(err)
	}
	defer handle.close()
	if err := handle.stop(); err != nil {
		t.Fatal(err)
	}
	if err := child.Wait(); err == nil {
		t.Fatal("expected signal exit")
	}
	if status, ok := child.ProcessState.Sys().(syscall.WaitStatus); !ok || status.Signal() != syscall.SIGKILL {
		t.Fatalf("did not escalate to exact process: %v", child.ProcessState)
	}
}

func TestPinnedHandleDoesNotRetargetAfterExit(t *testing.T) {
	child := exec.Command("sleep", "120")
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	defer child.Process.Kill()
	pid := fmt.Sprint(child.Process.Pid)
	handle, err := openProcessHandle(pid)
	if err != nil {
		t.Fatal(err)
	}
	defer handle.close()
	boot, ticks, err := processBirth(pid)
	if err != nil {
		t.Fatal(err)
	}
	if err := handle.verify(pid, boot, ticks); err != nil {
		t.Fatal(err)
	}
	if err := handle.verify(pid, boot, ticks+"0"); err == nil {
		t.Fatal("wrong birth accepted")
	}
	if err := child.Process.Signal(syscall.Signal(0)); err != nil {
		t.Fatal("verification signalled child", err)
	}
	_ = child.Process.Kill()
	_ = child.Wait()
	replacement := exec.Command("sleep", "120")
	if err := replacement.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = replacement.Process.Kill(); _ = replacement.Wait() }()
	if err := handle.signal(syscall.SIGKILL); err != syscall.ESRCH {
		t.Fatalf("dead descriptor result: %v", err)
	}
	if err := replacement.Process.Signal(syscall.Signal(0)); err != nil {
		t.Fatal("replacement affected", err)
	}
}

func TestRetainedDeadPaneIsNotRemovedOrAdopted(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	if _, err := run("set-option", "-w", "-t", proof.WindowID, "remain-on-exit", "on"); err != nil {
		t.Fatal(err)
	}
	if stopped, err := stopExactProcess(run, proof); err != nil || !stopped {
		t.Fatalf("stop: %v %v", stopped, err)
	}
	if output, err := run("display-message", "-p", "-t", proof.PaneID, "#{pane_dead}"); err != nil || output != "1" {
		t.Fatalf("retained pane: %s %v", output, err)
	}
	if state, err := checkExactWindow(run, proof); err != nil || state != "changed" {
		t.Fatalf("dead pane was adopted: %s %v", state, err)
	}
	if _, err := inspectExactWindow(run, proof.ConversationID); err == nil {
		t.Fatal("dead pane returned a live proof")
	}
}

func TestPaneAddedAfterObservationSurvivesPinnedStop(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	var otherPane string
	raced := func(args ...string) (string, error) {
		output, err := run(args...)
		if err != nil {
			return output, err
		}
		if len(args) > 0 && args[0] == "display-message" {
			otherPane, err = run("split-window", "-d", "-P", "-F", "#{pane_id}", "-t", proof.PaneID, "exec sleep 120")
		}
		return output, err
	}
	if stopped, err := stopExactProcess(raced, proof); err != nil || !stopped {
		t.Fatalf("pinned stop: %v %v", stopped, err)
	}
	output, err := run("display-message", "-p", "-t", otherPane, "#{pane_dead}")
	if err != nil || output != "0" {
		t.Fatalf("unrelated pane was affected: %s %v", output, err)
	}
}

func TestStopRefusesBirthMismatchAndRespawnDuringObservation(t *testing.T) {
	run := exactTestServer(t)
	proof := exactTestWindow(t, run, "a")
	wrong := proof
	wrong.ProcessStartTicks += "0"
	if stopped, err := stopExactProcess(run, wrong); stopped || err == nil {
		t.Fatalf("wrong birth stop: %v %v", stopped, err)
	}
	state, err := checkExactWindow(run, proof)
	if err != nil || state != "match" {
		t.Fatalf("original changed: %s %v", state, err)
	}
	raced := func(args ...string) (string, error) {
		output, err := run(args...)
		if err != nil {
			return output, err
		}
		if len(args) > 0 && args[0] == "display-message" {
			if _, err := run("respawn-pane", "-k", "-t", proof.PaneID, "exec sleep 120"); err != nil {
				return "", err
			}
			// Inject an exited original, not merely a requested respawn: tmux may
			// acknowledge before reaping it. Signalling the still-live pinned original
			// is safe, but does not exercise this refusal branch.
			deadline := time.Now().Add(time.Second)
			for !exactProcessGone(proof.PanePID) {
				if time.Now().After(deadline) {
					return "", fmt.Errorf("original did not exit during injected respawn")
				}
				time.Sleep(time.Millisecond)
			}
		}
		return output, nil
	}
	if stopped, err := stopExactProcess(raced, proof); stopped || err == nil {
		t.Fatalf("respawn raced through pinned handle: %v %v", stopped, err)
	}
	output, err := run("display-message", "-p", "-t", proof.PaneID, "#{pane_dead}|#{pane_pid}")
	if err != nil || !strings.HasPrefix(output, "0|") {
		t.Fatalf("replacement did not survive: %s %v", output, err)
	}
}
