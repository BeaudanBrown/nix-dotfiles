package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"unicode"
)

// Public host protocol only. Neither registry paths nor adapter credentials belong here.
type pickerHostCall func(context.Context, []string, any) error

type pickerConversation struct {
	ConversationID         string              `json:"conversationId"`
	Kind                   string              `json:"kind"`
	Title                  string              `json:"title"`
	CheckoutID             string              `json:"checkoutId,omitempty"`
	ProjectKey             string              `json:"projectKey,omitempty"`
	ActiveGenerationID     string              `json:"activeGenerationId"`
	RuntimeState           string              `json:"runtimeState"`
	LaunchState            string              `json:"launchState"`
	CheckoutDisplayName    string              `json:"checkoutDisplayName,omitempty"`
	ProjectDisplayName     string              `json:"projectDisplayName,omitempty"`
	SetupState             string              `json:"setupState"`
	Capabilities           []string            `json:"capabilities"`
	SessionKey             string              `json:"sessionKey,omitempty"`
	ErrorCode              string              `json:"errorCode,omitempty"`
	Window                 *pickerWindowResult `json:"window,omitempty"`
	Placement              *pickerPlacement    `json:"placement,omitempty"`
	ReconciliationRequired *bool               `json:"reconciliationRequired,omitempty"`
}
type pickerInventory struct {
	HostID string
	Rows   []pickerConversation
}
type pickerOpen struct {
	ConversationID string             `json:"conversationId"`
	LaunchID       string             `json:"launchId"`
	LaunchState    string             `json:"launchState"`
	Window         pickerWindowResult `json:"window"`
}

var pickerStableID = regexp.MustCompile(`^(generation|checkout|project|launch|session)_[a-f0-9]{32}$`)

func pickerID(value, prefix string) bool {
	return strings.HasPrefix(value, prefix+"_") && pickerStableID.MatchString(value)
}
func pickerText(value string, limit int) bool {
	return value != "" && len(value) <= limit && strings.IndexFunc(value, func(r rune) bool { return r < 32 || (r >= 127 && r <= 159) || r == 0xfffd || unicode.Is(unicode.Cf, r) }) < 0
}
func (row pickerConversation) valid() bool {
	if !validConversationID(row.ConversationID) || !pickerUnits(row.Title, 128) || !pickerID(row.ActiveGenerationID, "generation") || !containsString([]string{"running", "stopped", "unknown"}, row.RuntimeState) || !containsString([]string{"none", "prepared", "window_created", "attached", "failed"}, row.LaunchState) || !containsString([]string{"pending", "ready", "disconnected", "notification_setup_uncertain"}, row.SetupState) || !pickerValidCaps(row.Capabilities) {
		return false
	}
	if row.SessionKey != "" && !pickerID(row.SessionKey, "session") || row.ErrorCode != "" && !containsString(pickerErrorCodes, row.ErrorCode) || row.Window != nil && (!row.Window.valid() || row.Window.ConversationID != row.ConversationID) {
		return false
	}
	if row.Kind == "coordinator" {
		return row.CheckoutID == "" && row.ProjectKey == "" && row.CheckoutDisplayName == "" && row.ProjectDisplayName == "" && row.Placement == nil && row.ReconciliationRequired == nil
	}
	if row.Kind != "project" || row.CheckoutDisplayName != "" && !pickerUnits(row.CheckoutDisplayName, 128) || row.ProjectDisplayName != "" && !pickerUnits(row.ProjectDisplayName, 128) || row.Placement != nil && !row.Placement.valid() {
		return false
	}
	if row.CheckoutID != "" {
		return pickerID(row.CheckoutID, "checkout") && pickerID(row.ProjectKey, "project") && row.ReconciliationRequired == nil
	}
	return row.ReconciliationRequired != nil && *row.ReconciliationRequired && (row.ProjectKey == "" || pickerID(row.ProjectKey, "project"))
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
func loadPickerInventory(ctx context.Context, call pickerHostCall) (pickerInventory, error) {
	var result pickerInventory
	var status pickerHostStatus
	if err := call(ctx, []string{"host", "status"}, &status); err != nil {
		return result, err
	}
	// relayState describes Matrix connectivity, not availability of this local
	// authority. A disconnected Matrix bridge still owns retirement/open checks.
	if !status.valid() || !containsString(status.Capabilities, "window-first-open-v1") {
		return result, fmt.Errorf("managed host upgrade required")
	}
	result.HostID = status.HostID
	cursor := ""
	cursors := map[string]bool{}
	ids := map[string]bool{}
	for page := 0; page < 128; page++ {
		var data pickerInventoryPage
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
