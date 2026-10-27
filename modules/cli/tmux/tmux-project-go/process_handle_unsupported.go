//go:build !linux || (!amd64 && !arm64)

package main

import "fmt"

type processHandle struct{}

func openProcessHandle(string) (*processHandle, error) {
	return nil, fmt.Errorf("kernel process handles are unsupported")
}
func (*processHandle) close() {}
func (*processHandle) verify(string, string, string) error {
	return fmt.Errorf("kernel process handles are unsupported")
}
func (*processHandle) stop() error { return fmt.Errorf("kernel process handles are unsupported") }
func processBirth(string) (string, string, error) {
	return "", "", fmt.Errorf("kernel process identity is unsupported")
}
