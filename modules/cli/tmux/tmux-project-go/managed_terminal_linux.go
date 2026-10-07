//go:build linux

package main

import (
	"os"
	"syscall"
	"unsafe"
)

func managedTerminalAvailable(file *os.File) bool {
	var termios syscall.Termios
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, file.Fd(), syscall.TCGETS, uintptr(unsafe.Pointer(&termios)))
	return errno == 0
}
