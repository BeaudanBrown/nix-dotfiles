package main

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func pickerFixtureOpen() map[string]any {
	id := "conv_" + strings.Repeat("a", 32)
	return map[string]any{"conversationId": id, "launchId": "launch_" + strings.Repeat("a", 32), "launchState": "window_created", "window": map[string]any{"conversationId": id, "sessionName": "exact", "windowId": "@1", "paneId": "%1"}}
}
func TestPickerStrictPublicResponseSchemas(t *testing.T) {
	for _, mode := range []string{"valid", "case-row", "case-envelope", "matrix-disconnected", "missing-relay", "missing-account", "invalid-relay", "extra-status", "unknown-cap", "duplicate-cap", "invalid-host", "missing-checkout", "legacy-valid", "legacy-false", "legacy-extra-checkout", "coordinator-valid", "coordinator-project", "missing-setup", "setup-disconnected", "setup-pending", "setup-uncertain", "setup-invalid", "null-caps", "title-limit", "unicode-title-valid", "unicode-title-limit", "display-limit", "extra-row", "null-optional", "empty-optional", "placement-valid", "placement-traversal", "placement-missing-cwd", "placement-extra", "window-valid", "window-extra", "window-mismatch", "missing-cursor", "open-valid", "open-missing-window", "open-invalid-launch", "extra-envelope", "null-error", "wrong-request", "missing-ok", "error-valid"} {
		t.Run(mode, func(t *testing.T) {
			op := "conversation.list"
			var row map[string]any
			b, _ := json.Marshal(pickerFixtureRow("a"))
			_ = json.Unmarshal(b, &row)
			data := map[string]any{"items": []any{row}, "nextCursor": nil}
			expected := false
			switch mode {
			case "valid":
				expected = true
			case "case-row":
				row["Title"] = row["title"]
				delete(row, "title")
			case "matrix-disconnected", "missing-relay", "missing-account", "invalid-relay", "extra-status", "unknown-cap", "duplicate-cap", "invalid-host":
				op = "host.status"
				data = pickerFixtureStatus()
				switch mode {
				case "matrix-disconnected":
					data["relayState"] = "disconnected"
					expected = true
				case "missing-relay":
					delete(data, "relayState")
				case "missing-account":
					delete(data, "accountState")
				case "invalid-relay":
					data["relayState"] = "offline"
				case "extra-status":
					data["private"] = true
				case "unknown-cap":
					data["capabilities"] = []string{"future-v2"}
				case "duplicate-cap":
					data["capabilities"] = []string{"host-control-v1", "host-control-v1"}
				case "invalid-host":
					data["hostId"] = "not an identifier"
				}
			case "missing-checkout":
				delete(row, "checkoutId")
			case "legacy-valid", "legacy-false", "legacy-extra-checkout":
				row["reconciliationRequired"] = true
				if mode != "legacy-extra-checkout" {
					delete(row, "checkoutId")
				}
				if mode == "legacy-false" {
					row["reconciliationRequired"] = false
				}
				expected = mode == "legacy-valid"
			case "coordinator-valid", "coordinator-project":
				row["kind"] = "coordinator"
				delete(row, "checkoutId")
				if mode == "coordinator-valid" {
					delete(row, "projectKey")
					expected = true
				}
			case "setup-disconnected":
				row["setupState"] = "disconnected"
				expected = true
			case "setup-pending":
				row["setupState"] = "pending"
				expected = true
			case "setup-uncertain":
				row["setupState"] = "notification_setup_uncertain"
				expected = true
			case "setup-invalid":
				row["setupState"] = "failed"
			case "missing-setup":
				delete(row, "setupState")
			case "null-caps":
				row["capabilities"] = nil
			case "title-limit":
				row["title"] = strings.Repeat("a", 129)
			case "unicode-title-valid":
				row["title"] = strings.Repeat("😀", 128)
				expected = true
			case "unicode-title-limit":
				row["title"] = strings.Repeat("😀", 129)
			case "display-limit":
				row["checkoutDisplayName"] = strings.Repeat("a", 129)
			case "extra-row":
				row["privateRegistry"] = true
			case "null-optional":
				row["sessionKey"] = nil
			case "empty-optional":
				row["projectDisplayName"] = ""
			case "placement-valid", "placement-traversal", "placement-missing-cwd", "placement-extra":
				p := map[string]any{"rootKey": "work", "workspace": "repo", "relativeCwd": "src/pkg"}
				row["placement"] = p
				switch mode {
				case "placement-valid":
					expected = true
				case "placement-traversal":
					p["relativeCwd"] = "../other"
				case "placement-missing-cwd":
					delete(p, "relativeCwd")
				case "placement-extra":
					p["secret"] = true
				}
			case "window-valid", "window-extra", "window-mismatch":
				w := pickerFixtureOpen()["window"].(map[string]any)
				row["window"] = w
				switch mode {
				case "window-valid":
					expected = true
				case "window-extra":
					w["launchId"] = "launch_" + strings.Repeat("a", 32)
				case "window-mismatch":
					w["conversationId"] = "conv_" + strings.Repeat("b", 32)
				}
			case "missing-cursor":
				delete(data, "nextCursor")
			case "open-valid", "open-missing-window", "open-invalid-launch":
				op = "conversation.open"
				data = pickerFixtureOpen()
				switch mode {
				case "open-valid":
					expected = true
				case "open-missing-window":
					delete(data, "window")
				case "open-invalid-launch":
					data["launchId"] = "bad"
				}
			}
			envelope := map[string]any{"version": "1.0.0", "requestId": "picker_test", "ok": true, "data": data}
			switch mode {
			case "case-envelope":
				envelope["OK"] = true
				delete(envelope, "ok")
			case "extra-envelope":
				envelope["extra"] = true
			case "null-error":
				envelope["error"] = nil
			case "wrong-request":
				envelope["requestId"] = "other"
			case "missing-ok":
				delete(envelope, "ok")
			case "error-valid":
				envelope["ok"] = false
				delete(envelope, "data")
				envelope["error"] = map[string]any{"code": "retired", "message": "retired", "retryable": false}
			}
			raw, _ := json.Marshal(envelope)
			// Also consumed by the harness's real TypeBox parser conformance check.
			schemaValid := expected || mode == "wrong-request" || mode == "window-mismatch" || mode == "error-valid"
			fixture, _ := json.Marshal(map[string]any{"operation": op, "response": envelope, "valid": schemaValid})
			t.Logf("public-schema-fixture:%s", fixture)
			var target any
			err := decodePickerResponse(raw, &target, "picker_test", op)
			if (err == nil) != expected {
				t.Fatalf("expected valid=%v: %v", expected, err)
			}
		})
	}
}
func TestPickerDisconnectedMatrixRetainsLocalRetirementAuthority(t *testing.T) {
	call := func(_ context.Context, args []string, target any) error {
		var data any
		if args[0] == "host" {
			s := pickerFixtureStatus()
			s["relayState"] = "disconnected"
			data = s
		} else {
			data = map[string]any{"items": []pickerConversation{pickerFixtureRow("a")}, "nextCursor": nil}
		}
		raw, _ := json.Marshal(map[string]any{"version": "1.0.0", "requestId": "fixture", "ok": true, "data": data})
		op := "conversation.list"
		if args[0] == "host" {
			op = "host.status"
		}
		return decodePickerResponse(raw, target, "fixture", op)
	}
	got, err := loadPickerInventory(context.Background(), call)
	if err != nil || len(got.Rows) != 1 {
		t.Fatalf("Matrix transport is not local authority availability: %+v %v", got, err)
	}
}
