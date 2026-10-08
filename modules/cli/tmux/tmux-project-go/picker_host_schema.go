package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"reflect"
	"regexp"
	"strings"
	"unicode/utf8"
)

// Mirrors the three public response schemas this frontend consumes. Unknown
// fields fail closed; adding a public capability/shape requires a client update.
var pickerIdentifier = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`)
var pickerWorkspaceName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`)
var pickerCapabilities = []string{"host-control-v1", "approval-v1", "retirement-v1", "generation-navigation-v1", "commentary-v1", "notification-disposition-v1", "window-first-open-v1", "saved-session-open-v1", "saved-session-import-v1"}
var pickerErrorCodes = []string{"invalid_request", "unavailable", "not_found", "retired", "forbidden", "approval_required", "denied", "expired", "cancelled", "conflict", "busy", "stale_preview", "upgrade_required", "pending", "failed"}

type pickerHostStatus struct {
	HostID       string   `json:"hostId"`
	RelayState   string   `json:"relayState"`
	AccountState string   `json:"accountState"`
	Capabilities []string `json:"capabilities"`
}
type pickerInventoryPage struct {
	Items      []pickerConversation `json:"items"`
	NextCursor json.RawMessage      `json:"nextCursor"`
}
type pickerPlacement struct {
	RootKey     string  `json:"rootKey"`
	Workspace   string  `json:"workspace"`
	RelativeCwd *string `json:"relativeCwd"`
}
type pickerWindowResult struct {
	ConversationID string `json:"conversationId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
}

func pickerUnits(value string, limit int) bool {
	// Production TypeBox counts Unicode code points, not bytes/UTF-16 units.
	return pickerText(value, limit*4) && utf8.RuneCountInString(value) <= limit
}
func pickerValidCaps(values []string) bool {
	if values == nil || len(values) > len(pickerCapabilities) {
		return false
	}
	seen := map[string]bool{}
	for _, v := range values {
		if seen[v] || !containsString(pickerCapabilities, v) {
			return false
		}
		seen[v] = true
	}
	return true
}
func (s pickerHostStatus) valid() bool {
	return pickerIdentifier.MatchString(s.HostID) && containsString([]string{"ready", "disconnected"}, s.RelayState) && containsString([]string{"ready", "pending", "unavailable"}, s.AccountState) && pickerValidCaps(s.Capabilities)
}
func (w pickerWindowResult) valid() bool {
	return validConversationID(w.ConversationID) && pickerUnits(w.SessionName, 128) && exactWindowPattern.MatchString(w.WindowID) && exactPanePattern.MatchString(w.PaneID)
}
func (p pickerPlacement) valid() bool {
	if !pickerIdentifier.MatchString(p.RootKey) || !pickerWorkspaceName.MatchString(p.Workspace) || p.RelativeCwd == nil {
		return false
	}
	cwd := *p.RelativeCwd
	if cwd == "" {
		return true
	}
	if !pickerUnits(cwd, 512) || strings.HasPrefix(cwd, "/") || strings.Contains(cwd, "\\") {
		return false
	}
	for _, part := range strings.Split(cwd, "/") {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}

// encoding/json otherwise matches field names case-insensitively, unlike the
// exact public schema. Use the same struct tags to check keys recursively.
func pickerExactKeys(value any, typ reflect.Type) bool {
	if typ == reflect.TypeOf(json.RawMessage{}) {
		return true
	}
	for typ.Kind() == reflect.Pointer {
		typ = typ.Elem()
	}
	switch typ.Kind() {
	case reflect.Struct:
		fields, ok := value.(map[string]any)
		if !ok {
			return false
		}
		allowed := map[string]reflect.Type{}
		for i := 0; i < typ.NumField(); i++ {
			f := typ.Field(i)
			allowed[strings.Split(f.Tag.Get("json"), ",")[0]] = f.Type
		}
		for k, v := range fields {
			child, ok := allowed[k]
			if !ok || !pickerExactKeys(v, child) {
				return false
			}
		}
	case reflect.Slice:
		values, ok := value.([]any)
		if !ok {
			return false
		}
		for _, v := range values {
			if !pickerExactKeys(v, typ.Elem()) {
				return false
			}
		}
	}
	return true
}
func strictPickerJSON(data []byte, target any) error {
	var raw any
	if json.Unmarshal(data, &raw) != nil || !pickerExactKeys(raw, reflect.TypeOf(target)) {
		return fmt.Errorf("invalid exact public fields")
	}
	d := json.NewDecoder(bytes.NewReader(data))
	d.DisallowUnknownFields()
	if err := d.Decode(target); err != nil {
		return err
	}
	var extra any
	if d.Decode(&extra) != io.EOF {
		return fmt.Errorf("trailing public data")
	}
	return nil
}
func pickerNoNullOrEmpty(value any, key string) bool {
	switch v := value.(type) {
	case nil:
		return key == "nextCursor"
	case string:
		return v != "" || key == "relativeCwd"
	case map[string]any:
		for k, item := range v {
			if !pickerNoNullOrEmpty(item, k) {
				return false
			}
		}
	case []any:
		for _, item := range v {
			if !pickerNoNullOrEmpty(item, key) {
				return false
			}
		}
	}
	return true
}
func validatePickerData(operation string, data []byte) error {
	var raw any
	if json.Unmarshal(data, &raw) != nil || !pickerNoNullOrEmpty(raw, "") {
		return fmt.Errorf("invalid null/empty public field")
	}
	valid := false
	switch operation {
	case "host.status":
		var value pickerHostStatus
		valid = strictPickerJSON(data, &value) == nil && value.valid()
	case "conversation.list":
		var value pickerInventoryPage
		if strictPickerJSON(data, &value) == nil && value.Items != nil && len(value.Items) <= 100 {
			valid = true
			for _, row := range value.Items {
				if !row.valid() {
					valid = false
				}
			}
			if string(value.NextCursor) != "null" {
				var cursor string
				if json.Unmarshal(value.NextCursor, &cursor) != nil || !pickerUnits(cursor, 256) {
					valid = false
				}
			}
		}
	case "conversation.open":
		var value pickerOpen
		valid = strictPickerJSON(data, &value) == nil && validConversationID(value.ConversationID) && pickerID(value.LaunchID, "launch") && containsString([]string{"none", "prepared", "window_created", "attached", "failed"}, value.LaunchState) && value.Window.valid() && value.ConversationID == value.Window.ConversationID
	}
	if !valid {
		return fmt.Errorf("invalid public %s response", operation)
	}
	return nil
}
func decodePickerResponse(data []byte, target any, expectedID, operation string) error {
	var raw any
	if len(data) > 65536 || json.Unmarshal(data, &raw) != nil || !pickerNoNullOrEmpty(raw, "") {
		return fmt.Errorf("invalid public envelope")
	}
	var response struct {
		Version   string          `json:"version"`
		RequestID string          `json:"requestId"`
		OK        *bool           `json:"ok"`
		Data      json.RawMessage `json:"data"`
		Error     *struct {
			Code      string `json:"code"`
			Message   string `json:"message"`
			Retryable *bool  `json:"retryable"`
		} `json:"error"`
	}
	if len(data) > 65536 || strictPickerJSON(data, &response) != nil || response.Version != "1.0.0" || response.OK == nil || !pickerIdentifier.MatchString(response.RequestID) || expectedID == "" || response.RequestID != expectedID {
		return fmt.Errorf("invalid managed host response identity")
	}
	if !*response.OK {
		if len(response.Data) != 0 || response.Error == nil || response.Error.Retryable == nil || !containsString(pickerErrorCodes, response.Error.Code) || !pickerUnits(response.Error.Message, 512) {
			return fmt.Errorf("invalid public host refusal")
		}
		return fmt.Errorf("managed host refused: %s", response.Error.Code)
	}
	if response.Error != nil {
		return fmt.Errorf("conflicting public response variants")
	}
	if err := validatePickerData(operation, response.Data); err != nil {
		return err
	}
	return json.Unmarshal(response.Data, target)
}
