package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestResolveManagedWorkspaceRequiresRealImmediateChild(t *testing.T) {
	root := t.TempDir()
	workspace := filepath.Join(root, "project")
	if err := os.Mkdir(workspace, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)

	resolved, err := resolveManagedWorkspace(workspacePlacement{RootKey: "projects", Workspace: "project", RelativeCwd: ""})
	if err != nil {
		t.Fatalf("valid immediate child was rejected: %v", err)
	}
	if resolved.WorkspacePath != workspace || resolved.Cwd != workspace {
		t.Fatalf("unexpected resolution: %#v", resolved)
	}

	for _, placement := range []workspacePlacement{
		{RootKey: "projects", Workspace: ".", RelativeCwd: ""},
		{RootKey: "projects", Workspace: "..", RelativeCwd: ""},
		{RootKey: "projects", Workspace: "project", RelativeCwd: ".."},
	} {
		if _, err := resolveManagedWorkspace(placement); err == nil {
			t.Fatalf("unsafe placement was accepted: %#v", placement)
		}
	}

	outside := t.TempDir()
	if err := os.Symlink(outside, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	if _, err := resolveManagedWorkspace(workspacePlacement{RootKey: "projects", Workspace: "linked"}); err == nil {
		t.Fatal("symlinked workspace escaped its configured root")
	}
}

func TestManagedProjectWindowResultPreservesEmptyRelativeCwd(t *testing.T) {
	encoded, err := json.Marshal(managedProjectWindowResult{
		ConversationID: "conv_0123456789abcdef0123456789abcdef",
		SessionName:    "project",
		WindowID:       "@7",
		PaneID:         "%8",
		Role:           "conversation",
		RootKey:        "projects",
		Workspace:      "project",
		RelativeCwd:    "",
	})
	if err != nil {
		t.Fatal(err)
	}
	var response map[string]any
	if err := json.Unmarshal(encoded, &response); err != nil {
		t.Fatal(err)
	}
	if relativeCwd, present := response["relativeCwd"]; !present || relativeCwd != "" {
		t.Fatalf("project window response must preserve an empty relativeCwd: %s", encoded)
	}
}

func TestSafeRelativePath(t *testing.T) {
	for _, valid := range []string{"", "src", "src/module"} {
		if !safeRelativePath(valid) {
			t.Fatalf("valid relative path rejected: %q", valid)
		}
	}
	for _, invalid := range []string{".", "..", "/tmp", "src//module", "src/../other", `src\\other`} {
		if safeRelativePath(invalid) {
			t.Fatalf("unsafe relative path accepted: %q", invalid)
		}
	}
}

func quoteJSON(value string) string {
	quoted := `"`
	for _, r := range value {
		switch r {
		case '\\', '"':
			quoted += `\\` + string(r)
		default:
			quoted += string(r)
		}
	}
	return quoted + `"`
}
