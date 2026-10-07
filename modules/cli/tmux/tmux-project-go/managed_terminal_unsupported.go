//go:build !linux

package main

import "os"

// Exact kernel-owned lifecycle attachment is currently Linux-only.
func managedTerminalAvailable(_ *os.File) bool { return false }
