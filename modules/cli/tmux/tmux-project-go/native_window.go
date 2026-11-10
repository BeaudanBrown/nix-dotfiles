package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// One window primitive, not a host/session lifecycle API. The harness helper
// serializes native-file opens; Pi's kernel lock is the sole writer authority.
func nativeWindow(input io.Reader, output io.Writer) error {
	var request struct {
		Cwd  string   `json:"cwd"`
		Argv []string `json:"argv"`
	}
	data, err := io.ReadAll(io.LimitReader(input, 65537))
	if err != nil || len(data) > 65536 {
		return fmt.Errorf("native window request exceeds bound")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		return err
	}
	// tmux's one-string form runs a shell command, not a literal executable.
	if decoder.Decode(new(any)) != io.EOF || len(request.Argv) < 2 || len(request.Argv) > 32 || !filepath.IsAbs(request.Argv[0]) {
		return fmt.Errorf("invalid native window argv")
	}
	for _, arg := range request.Argv {
		if len(arg) > 8192 || strings.ContainsRune(arg, 0) {
			return fmt.Errorf("invalid native argument")
		}
	}
	cwd := pickerCanonical(request.Cwd)
	if cwd == "" || cwd != request.Cwd {
		return fmt.Errorf("native workspace is unavailable or changed")
	}
	// Use the same ordinary workspace placement as a local shell. No Git,
	// coordinator, account-ready, bridge connection, or generation is required.
	session, err := ensureProjectSession(cwd)
	if err != nil {
		return err
	}
	args := []string{"new-window", "-d", "-P", "-F", "#{pane_id}", "-t", "=" + session, "-c", tmuxLiteral(cwd), "-n", "Pi", "--"}
	for _, arg := range request.Argv {
		args = append(args, tmuxLiteral(arg))
	}
	pane, err := tmux(args...)
	if err != nil {
		return err
	}
	if !exactPanePattern.MatchString(pane) {
		return fmt.Errorf("invalid new native pane")
	}
	return json.NewEncoder(output).Encode(map[string]string{"pane": pane})
}
func runNativeWindow() error { return nativeWindow(os.Stdin, os.Stdout) }
