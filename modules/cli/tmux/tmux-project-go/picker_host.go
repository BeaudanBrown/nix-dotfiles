package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

// Public host CLI only. Neither registry paths nor adapter credentials belong here.
type pickerHostCall func(context.Context, []string, any) error

type pickerConversation struct {
	ConversationID      string `json:"conversationId"`
	Kind                string `json:"kind"`
	Title               string `json:"title"`
	CheckoutID          string `json:"checkoutId"`
	ProjectKey          string `json:"projectKey"`
	ActiveGenerationID  string `json:"activeGenerationId"`
	RuntimeState        string `json:"runtimeState"`
	LaunchState         string `json:"launchState"`
	CheckoutDisplayName string `json:"checkoutDisplayName"`
}
type pickerInventory struct {
	HostID string
	Rows   []pickerConversation
}
type pickerOpen struct {
	ConversationID string `json:"conversationId"`
	LaunchID       string `json:"launchId"`
	LaunchState    string `json:"launchState"`
	Window         struct {
		ConversationID string `json:"conversationId"`
		SessionName    string `json:"sessionName"`
		WindowID       string `json:"windowId"`
		PaneID         string `json:"paneId"`
	} `json:"window"`
}

var pickerStableID = regexp.MustCompile(`^(generation|checkout|project)_[a-f0-9]{32}$`)

func pickerID(value, prefix string) bool {
	return strings.HasPrefix(value, prefix+"_") && pickerStableID.MatchString(value)
}
func pickerText(value string, limit int) bool {
	return value != "" && len(value) <= limit && strings.IndexFunc(value, func(r rune) bool { return r < 32 || r == 127 || r == 0xfffd }) < 0
}
func (row pickerConversation) valid() bool {
	return validConversationID(row.ConversationID) && (row.Kind == "project" || row.Kind == "coordinator") && pickerText(row.Title, 512) &&
		pickerID(row.ActiveGenerationID, "generation") && containsString([]string{"running", "stopped", "unknown"}, row.RuntimeState) &&
		containsString([]string{"none", "prepared", "window_created", "attached", "failed"}, row.LaunchState) &&
		(row.CheckoutID == "" || (pickerID(row.CheckoutID, "checkout") && pickerID(row.ProjectKey, "project")))
}
func containsString(values []string, value string) bool {
	for _, item := range values {
		if item == value {
			return true
		}
	}
	return false
}

type pickerBoundedOutput struct {
	bytes.Buffer
	limit int
}

func (b *pickerBoundedOutput) Write(p []byte) (int, error) {
	if len(p) > b.limit-b.Len() {
		return 0, fmt.Errorf("host output exceeds bound")
	}
	return b.Buffer.Write(p)
}
func callPickerHost(ctx context.Context, args []string, target any) error {
	cmd := exec.CommandContext(ctx, "pi-managed-session", append(args, "--json")...)
	out := &pickerBoundedOutput{limit: 65536}
	stderr := &pickerBoundedOutput{limit: 4096}
	cmd.Stdout, cmd.Stderr = out, stderr
	cmd.WaitDelay = 100 * time.Millisecond
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("managed host unavailable or action refused; inspect host before retrying")
	}
	var response struct {
		Version   string          `json:"version"`
		RequestID string          `json:"requestId"`
		OK        bool            `json:"ok"`
		Data      json.RawMessage `json:"data"`
	}
	dec := json.NewDecoder(bytes.NewReader(out.Bytes()))
	if dec.Decode(&response) != nil || response.Version != "1.0.0" || !response.OK || !pickerText(response.RequestID, 128) {
		return fmt.Errorf("invalid managed host response")
	}
	var extra any
	if dec.Decode(&extra) != io.EOF {
		return fmt.Errorf("trailing managed host response")
	}
	return json.Unmarshal(response.Data, target)
}
func loadPickerInventory(ctx context.Context, call pickerHostCall) (pickerInventory, error) {
	var result pickerInventory
	var status struct {
		HostID       string   `json:"hostId"`
		Capabilities []string `json:"capabilities"`
	}
	if err := call(ctx, []string{"host", "status"}, &status); err != nil {
		return result, err
	}
	if !pickerText(status.HostID, 128) || !containsString(status.Capabilities, "window-first-open-v1") {
		return result, fmt.Errorf("managed host upgrade required")
	}
	result.HostID = status.HostID
	cursor := ""
	cursors := map[string]bool{}
	ids := map[string]bool{}
	for page := 0; page < 128; page++ {
		var data struct {
			Items      []pickerConversation `json:"items"`
			NextCursor json.RawMessage      `json:"nextCursor"`
		}
		args := []string{"conversation", "list", "--limit", "100"}
		if cursor != "" {
			args = append(args, "--cursor", cursor)
		}
		if err := call(ctx, args, &data); err != nil {
			return pickerInventory{}, err
		}
		if data.Items == nil || len(data.Items) > 100 || len(result.Rows)+len(data.Items) > 4096 {
			return pickerInventory{}, fmt.Errorf("invalid inventory size")
		}
		for _, row := range data.Items {
			if !row.valid() || ids[row.ConversationID] {
				return pickerInventory{}, fmt.Errorf("invalid inventory identity")
			}
			ids[row.ConversationID] = true
			result.Rows = append(result.Rows, row)
		}
		if string(data.NextCursor) == "null" {
			return result, nil
		}
		if json.Unmarshal(data.NextCursor, &cursor) != nil {
			return pickerInventory{}, fmt.Errorf("invalid inventory cursor")
		}
		if !pickerText(cursor, 256) || cursors[cursor] {
			return pickerInventory{}, fmt.Errorf("invalid inventory cursor")
		}
		cursors[cursor] = true
	}
	return pickerInventory{}, fmt.Errorf("inventory exceeds page bound")
}
func openPickerConversation(ctx context.Context, call pickerHostCall, row pickerConversation, client, pid string, run exactTmux) error {
	if !row.valid() || !validManagedClientName(client) || !exactPID(pid) {
		return fmt.Errorf("invalid picker selection")
	}
	current, err := capturePickerClient(client, run)
	if err != nil || current != pid {
		return fmt.Errorf("requester changed before admission")
	}
	// The host checks retirement/generation again during open. Never replay an
	// uncertain open or cancel a host launch when this UI disappears.
	var opened pickerOpen
	if err := call(ctx, []string{"conversation", "open", row.ConversationID, "--expected-generation-id", row.ActiveGenerationID}, &opened); err != nil {
		return err
	}
	if opened.ConversationID != row.ConversationID || opened.Window.ConversationID != row.ConversationID ||
		!containsString([]string{"window_created", "attached"}, opened.LaunchState) {
		return fmt.Errorf("managed open identity changed")
	}
	return focusExactWindow(run, managedFocusRequest{ConversationID: row.ConversationID, LaunchID: opened.LaunchID, SessionName: opened.Window.SessionName,
		WindowID: opened.Window.WindowID, PaneID: opened.Window.PaneID, ClientName: client, ClientPID: pid})
}
