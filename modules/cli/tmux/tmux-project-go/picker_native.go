package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"unicode"
)

// The picker consumes only this local native-file interface. It never reads a
// bridge database, negotiates host capabilities, or contacts Matrix/the relay.
type pickerNativeCall func(context.Context, []string, any) error
type pickerNativeSession struct {
	Version   int    `json:"version"`
	File      string `json:"file"`
	ID        string `json:"id"`
	Cwd       string `json:"cwd"`
	Title     string `json:"title"`
	Running   bool   `json:"running"`
	Pending   bool   `json:"pending,omitempty"`
	Pane      string `json:"pane,omitempty"`
	ServerPID int    `json:"serverPid,omitempty"`
	Archived  bool   `json:"archived,omitempty"`
}
type pickerInventory struct{ Rows []pickerNativeSession }

func pickerText(value string, limit int) bool {
	return value != "" && len(value) <= limit && strings.IndexFunc(value, func(r rune) bool { return r < 32 || (r >= 127 && r <= 159) || r == 0xfffd || unicode.Is(unicode.Cf, r) }) < 0
}
func pickerLabel(value string) string {
	runes := []rune(strings.Map(func(r rune) rune {
		if r < 32 || (r >= 127 && r <= 159) || unicode.Is(unicode.Cf, r) {
			return ' '
		}
		return r
	}, value))
	if len(runes) > 160 {
		runes = append(runes[:160], '…')
	}
	return string(runes)
}
func (row pickerNativeSession) valid() bool {
	return row.Version == 1 && filepath.IsAbs(row.File) && filepath.Clean(row.File) == row.File && pickerText(row.File, 4096) && filepath.IsAbs(row.Cwd) && pickerText(row.Cwd, 4096) && pickerText(row.ID, 128) && (row.Pane == "" || exactPanePattern.MatchString(row.Pane) && row.ServerPID > 0)
}

type pickerBoundedOutput struct {
	bytes.Buffer
	limit int
}

func (b *pickerBoundedOutput) Write(p []byte) (int, error) {
	if len(p) > b.limit-b.Len() {
		return 0, fmt.Errorf("picker output exceeds bound")
	}
	return b.Buffer.Write(p)
}
func callPickerNative(ctx context.Context, args []string, target any) error {
	helper := os.Getenv("PI_NATIVE_SESSION_HELPER")
	if helper == "" {
		helper = "pi-session"
	} else if !filepath.IsAbs(helper) {
		return fmt.Errorf("PI_NATIVE_SESSION_HELPER must be an absolute executable")
	}
	cmd := exec.CommandContext(ctx, helper, args...)
	out, stderr := &pickerBoundedOutput{limit: 8 * 1024 * 1024}, &pickerBoundedOutput{limit: 65536}
	cmd.Stdout, cmd.Stderr = out, stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("local Pi helper: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return json.Unmarshal(out.Bytes(), target)
}
func loadPickerInventory(ctx context.Context, call pickerNativeCall) (pickerInventory, error) {
	var rows []pickerNativeSession
	if err := call(ctx, []string{"list", "--all"}, &rows); err != nil {
		return pickerInventory{}, err
	}
	if rows == nil || len(rows) > 4096 {
		return pickerInventory{}, fmt.Errorf("invalid native inventory size")
	}
	seen := map[string]bool{}
	var result pickerInventory
	for _, row := range rows {
		if !row.valid() || seen[row.File] {
			continue
		} // Bad metadata cannot hide unrelated local sessions.
		seen[row.File] = true
		result.Rows = append(result.Rows, row)
	}
	return result, nil
}
func openPickerNative(ctx context.Context, call pickerNativeCall, row pickerNativeSession, client, pid string, run exactTmux) error {
	if !row.valid() || row.Archived || !validClientName(client) || !exactPID(pid) {
		return fmt.Errorf("invalid native selection")
	}
	current, err := capturePickerClient(client, run)
	if err != nil || current != pid {
		return fmt.Errorf("requester changed before local open")
	}
	var opened pickerNativeSession
	if err := call(ctx, []string{"open", row.File, "--expected-id", row.ID}, &opened); err != nil {
		return err
	}
	if !opened.valid() || opened.File != row.File || opened.ID != row.ID {
		return fmt.Errorf("selected native identity changed")
	}
	if opened.Pane == "" {
		return fmt.Errorf("native writer is active outside this tmux server; use its local terminal")
	}
	value, err := run("display-message", "-p", "-t", opened.Pane, "#{session_name}\t#{window_id}\t#{pane_id}\t#{pid}")
	if err != nil {
		return err
	}
	fields := strings.Split(strings.TrimSpace(value), "\t")
	if len(fields) != 4 || fields[2] != opened.Pane || fields[3] != strconv.Itoa(opened.ServerPID) {
		return fmt.Errorf("native window changed")
	}
	return focusPickerWindow(pickerWindow{Session: fields[0], Window: fields[1], Pane: fields[2]}, client, pid, opened.ServerPID, run)
}
