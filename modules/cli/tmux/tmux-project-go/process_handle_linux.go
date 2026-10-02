//go:build linux && (amd64 || arm64)

package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Linux assigns these syscall numbers on both supported architectures. Never
// fall back to kill(pid): a descriptor pins one kernel process lifetime.
const sysPidfdOpen = 434
const sysPidfdSendSignal = 424

type processHandle struct{ fd int }

func openProcessHandle(pid string) (*processHandle, error) {
	if !exactPID(pid) {
		return nil, fmt.Errorf("invalid process identity")
	}
	number, _ := strconv.Atoi(pid)
	fd, _, errno := syscall.Syscall(sysPidfdOpen, uintptr(number), 0, 0)
	if errno != 0 {
		return nil, fmt.Errorf("kernel process handle unavailable: %w", errno)
	}
	return &processHandle{int(fd)}, nil
}
func (p *processHandle) close() { _ = syscall.Close(p.fd) }
func (p *processHandle) signal(signal syscall.Signal) error {
	_, _, errno := syscall.Syscall6(sysPidfdSendSignal, uintptr(p.fd), uintptr(signal), 0, 0, 0, 0)
	if errno != 0 {
		return errno
	}
	return nil
}
func processBirth(pid string) (boot, ticks string, err error) {
	if !exactPID(pid) {
		return "", "", fmt.Errorf("invalid process identity")
	}
	bootBytes, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return "", "", err
	}
	stat, err := os.ReadFile("/proc/" + pid + "/stat")
	if err != nil {
		return "", "", err
	}
	// comm may contain spaces and parentheses; fields after its last ')' start
	// at field 3. starttime is field 22, hence index 19 in this suffix.
	end := strings.LastIndexByte(string(stat), ')')
	if end < 0 || len(stat) > 65536 {
		return "", "", fmt.Errorf("invalid process observation")
	}
	fields := strings.Fields(string(stat[end+1:]))
	if len(fields) < 20 {
		return "", "", fmt.Errorf("invalid process observation")
	}
	boot, ticks = strings.TrimSpace(string(bootBytes)), fields[19]
	if !exactBootPattern.MatchString(boot) || !exactStartPattern.MatchString(ticks) {
		return "", "", fmt.Errorf("invalid process birth identity")
	}
	return boot, ticks, nil
}
func (p *processHandle) verify(pid, boot, ticks string) error {
	actualBoot, actualTicks, err := processBirth(pid)
	if err != nil || actualBoot != boot || actualTicks != ticks {
		return fmt.Errorf("process birth identity changed")
	}
	// If PID reuse occurred during the read, this descriptor still refers to
	// the previous process. It must remain live after verifying the read.
	if err := p.signal(0); err != nil {
		return fmt.Errorf("pinned process is no longer live: %w", err)
	}
	return nil
}
func (p *processHandle) stop() error {
	if err := p.signal(syscall.SIGTERM); err != nil && err != syscall.ESRCH {
		return err
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if err := p.signal(0); err == syscall.ESRCH {
			return nil
		} else if err != nil {
			return err
		}
		time.Sleep(20 * time.Millisecond)
	}
	// Escalation uses the same pinned handle, never a new PID lookup.
	if err := p.signal(syscall.SIGKILL); err != nil && err != syscall.ESRCH {
		return err
	}
	return nil
}
