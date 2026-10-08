package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"
)

// Native client of the existing documented host-control-v1 socket, not a
// private-registry reader. Match the public CLI's endpoint ownership checks and
// human-local envelope. One request, one bounded EOF-terminated LF frame; no retry.
func callPickerHost(ctx context.Context, args []string, target any) error {
	directory := strings.TrimSpace(os.Getenv("PI_MANAGED_SESSIONS_RUNTIME_DIR"))
	if directory == "" {
		if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
			directory = filepath.Join(runtime, "pi-managed-sessions")
		}
	}
	if directory == "" {
		return callPickerHostCLI(ctx, args, target)
	}
	if !filepath.IsAbs(directory) {
		return fmt.Errorf("managed host endpoint unavailable")
	}
	action, err := pickerHostAction(args)
	if err != nil {
		return err
	}
	socket := filepath.Join(directory, "control.sock")
	for _, path := range []string{directory, socket} {
		st, err := os.Lstat(path)
		if err != nil {
			return fmt.Errorf("managed host unavailable")
		}
		owner, ok := st.Sys().(*syscall.Stat_t)
		if !ok || int(owner.Uid) != os.Getuid() || st.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("managed host endpoint is not owned")
		}
		if path == directory {
			if !st.IsDir() || st.Mode().Perm()&0077 != 0 {
				return fmt.Errorf("managed host directory is not private")
			}
		} else if st.Mode()&os.ModeSocket == 0 || st.Mode().Perm() != 0600 {
			return fmt.Errorf("managed host socket is not private")
		}
	}
	nonce := make([]byte, 16)
	if _, err = rand.Read(nonce); err != nil {
		return err
	}
	id := "picker_" + hex.EncodeToString(nonce)
	request, _ := json.Marshal(map[string]any{"version": "1.0.0", "actor": map[string]string{"kind": "human_local", "requestId": id}, "action": action})
	conn, err := (&net.Dialer{}).DialContext(ctx, "unix", socket)
	if err != nil {
		return fmt.Errorf("managed host unavailable")
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()
	deadline := time.Now().Add(30 * time.Second)
	if requested, ok := ctx.Deadline(); ok && requested.Before(deadline) {
		deadline = requested
	}
	if err = conn.SetDeadline(deadline); err != nil {
		return err
	}
	if _, err = conn.Write(append(request, '\n')); err != nil {
		return fmt.Errorf("host request outcome unknown; inspect before retrying")
	}
	response, err := io.ReadAll(io.LimitReader(conn, 65537))
	if err != nil {
		return fmt.Errorf("host request outcome unknown; inspect before retrying")
	}
	if len(response) == 0 || len(response) > 65536 || bytes.IndexByte(response, '\n') != len(response)-1 || !utf8.Valid(response) {
		return fmt.Errorf("invalid host response frame")
	}
	return decodePickerResponse(response, target, id)
}
func pickerHostAction(args []string) (map[string]any, error) {
	if len(args) == 2 && args[0] == "host" && args[1] == "status" {
		return map[string]any{"operation": "host.status"}, nil
	}
	if len(args) >= 2 && args[0] == "conversation" && args[1] == "list" {
		action := map[string]any{"operation": "conversation.list"}
		for index := 2; index < len(args); index += 2 {
			if index+1 >= len(args) {
				return nil, fmt.Errorf("invalid inventory arguments")
			}
			switch args[index] {
			case "--limit":
				n, err := strconv.Atoi(args[index+1])
				if err != nil || n < 1 || n > 100 {
					return nil, fmt.Errorf("invalid page size")
				}
				action["limit"] = n
			case "--cursor":
				if !pickerText(args[index+1], 256) {
					return nil, fmt.Errorf("invalid cursor")
				}
				action["cursor"] = args[index+1]
			default:
				return nil, fmt.Errorf("unsupported inventory option")
			}
		}
		return action, nil
	}
	if len(args) == 5 && args[0] == "conversation" && args[1] == "open" && validConversationID(args[2]) && args[3] == "--expected-generation-id" && pickerID(args[4], "generation") {
		return map[string]any{"operation": "conversation.open", "conversationId": args[2], "expectedGenerationId": args[4]}, nil
	}
	return nil, fmt.Errorf("unsupported picker host action")
}
