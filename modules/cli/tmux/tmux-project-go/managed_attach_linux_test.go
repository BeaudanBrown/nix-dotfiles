//go:build linux

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
	"unsafe"
)

func attachTestPTY(t *testing.T) (*os.File, *os.File, string) {
	t.Helper()
	master, err := os.OpenFile("/dev/ptmx", os.O_RDWR|syscall.O_NOCTTY, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { master.Close() })
	var unlock, number uint32
	if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, master.Fd(), syscall.TIOCSPTLCK, uintptr(unsafe.Pointer(&unlock))); errno != 0 {
		t.Fatal(errno)
	}
	if _, _, errno := syscall.Syscall(syscall.SYS_IOCTL, master.Fd(), syscall.TIOCGPTN, uintptr(unsafe.Pointer(&number))); errno != 0 {
		t.Fatal(errno)
	}
	slave, err := os.OpenFile(fmt.Sprintf("/dev/pts/%d", number), os.O_RDWR|syscall.O_NOCTTY, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { slave.Close() })
	log, err := os.Create(filepath.Join(t.TempDir(), "pty.log"))
	if err != nil {
		t.Fatal(err)
	}
	go func() { defer log.Close(); _, _ = io.Copy(log, master) }()
	return master, slave, log.Name()
}

func TestManagedAttachUsesRealControllingTerminal(t *testing.T) {
	if os.Getenv("PI_TEST_ATTACH_REQUEST") != "" {
		if err := managed([]string{"window-attach-exact"}); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		os.Exit(0)
	}
	for _, stale := range []bool{false, true} {
		t.Run(fmt.Sprintf("late-replacement-%t", stale), func(t *testing.T) {
			run := exactTestServer(t)
			proof := exactTestWindow(t, run, "a")
			socket, err := run("display-message", "-p", "#{socket_path}")
			if err != nil {
				t.Fatal(err)
			}
			realTmux, err := exec.LookPath("tmux")
			if err != nil {
				t.Fatal(err)
			}
			root := t.TempDir()
			script := "#!/bin/sh\n"
			if stale {
				script += "if [ \"$1\" = if-shell ]; then " + shellQuote(realTmux) + " -S " + shellQuote(socket) + " set-option -w -t " + shellQuote(proof.WindowID) + " " + exactLaunchOption + " launch_" + strings.Repeat("b", 32) + "; fi\n"
			}
			script += "exec " + shellQuote(realTmux) + " -S " + shellQuote(socket) + " \"$@\"\n"
			if err := os.WriteFile(filepath.Join(root, "tmux"), []byte(script), 0700); err != nil {
				t.Fatal(err)
			}
			request := managedAttachRequest{proof.ConversationID, proof.LaunchID, proof.SessionName, proof.WindowID, proof.PaneID}
			wire, _ := json.Marshal(request)
			requestPath := filepath.Join(root, "request.json")
			if err := os.WriteFile(requestPath, wire, 0600); err != nil {
				t.Fatal(err)
			}
			_, slave, logPath := attachTestPTY(t)
			command := exec.Command(os.Args[0], "-test.run=^TestManagedAttachUsesRealControllingTerminal$")
			command.Env = append(os.Environ(), "PATH="+root, "TERM=xterm-256color", "TMUX=", "XDG_RUNTIME_DIR="+filepath.Dir(socket), "TMUX_TMPDIR="+filepath.Dir(socket), "PI_TEST_ATTACH_REQUEST="+requestPath)
			input, err := os.Open(requestPath)
			if err != nil {
				t.Fatal(err)
			}
			defer input.Close()
			command.Stdin = input
			command.Stdout = slave
			command.Stderr = slave
			command.SysProcAttr = &syscall.SysProcAttr{Setsid: true, Setctty: true, Ctty: 1}
			if err := command.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = command.Process.Kill() })
			done := make(chan error, 1)
			go func() { done <- command.Wait() }()
			if !stale {
				deadline := time.Now().Add(5 * time.Second)
				attached := false
				for time.Now().Before(deadline) {
					rows, _ := run("list-clients", "-F", "#{client_name}\t#{window_id}\t#{pane_id}")
					parts := strings.Split(strings.TrimSpace(rows), "\t")
					if len(parts) == 3 {
						if parts[1] != proof.WindowID || parts[2] != proof.PaneID {
							t.Fatalf("wrong attachment: %q", rows)
						}
						if _, err := run("detach-client", "-t", parts[0]); err != nil {
							t.Fatal(err)
						}
						attached = true
						break
					}
					time.Sleep(10 * time.Millisecond)
				}
				if !attached {
					output, _ := os.ReadFile(logPath)
					t.Fatalf("no exact terminal attachment observed: %q", output)
				}
			}
			select {
			case err := <-done:
				if (err != nil) != stale {
					output, _ := os.ReadFile(logPath)
					t.Fatalf("attach exit: %v (stale=%t): %q", err, stale, output)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("attachment failed to terminate")
			}
			if rows, _ := run("list-clients", "-F", "#{client_name}"); strings.TrimSpace(rows) != "" {
				t.Fatalf("unexpected surviving client: %q", rows)
			}
		})
	}
}

func TestManagedAttachRejectsNonterminalWithoutWritingIt(t *testing.T) {
	file, err := os.CreateTemp(t.TempDir(), "redirected-stdout")
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if _, err := file.WriteString("preserve"); err != nil {
		t.Fatal(err)
	}
	original := os.Stdout
	os.Stdout = file
	defer func() { os.Stdout = original }()
	if _, err := managedTerminalCommand("display-message", "unexpected"); err == nil {
		t.Fatal("nonterminal accepted")
	}
	bytes, err := os.ReadFile(file.Name())
	if err != nil || string(bytes) != "preserve" {
		t.Fatalf("redirected stdout changed: %q %v", bytes, err)
	}
}

func TestManagedAttachBoundsCommandOutput(t *testing.T) {
	var output attachOutput
	data := []byte(strings.Repeat("x", 70000))
	if count, err := output.Write(data); err != nil || count != len(data) || !output.overflow || output.text.Len() != 65536 {
		t.Fatal("output bound failed")
	}
	if count, err := output.Write(data); err != nil || count != len(data) || output.text.Len() != 65536 {
		t.Fatal("overflow did not drain")
	}
}
