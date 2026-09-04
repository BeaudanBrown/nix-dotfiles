package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
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

func TestCreateManagedProjectInitializesBoundLocalGitRepository(t *testing.T) {
	root := t.TempDir()
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)
	request := projectCreateRequest{CreationKey: "create-safe", RootKey: "projects", Workspace: "safe-project"}

	created, err := createManagedProject(request)
	if err != nil {
		t.Fatalf("create managed project: %v", err)
	}
	target := filepath.Join(root, "safe-project")
	expected := resolvedWorkspace{
		workspacePlacement: workspacePlacement{RootKey: "projects", Workspace: "safe-project", RelativeCwd: ""},
		WorkspacePath:      target,
		Cwd:                target,
	}
	if !reflect.DeepEqual(created, expected) {
		t.Fatalf("unexpected creation result: %#v", created)
	}
	entries, err := os.ReadDir(target)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Name() != ".git" {
		t.Fatalf("project creation added state outside Git metadata: %#v", entries)
	}
	if got := testGitOutput(t, target, "symbolic-ref", "--short", "HEAD"); got != "main" {
		t.Fatalf("project branch = %q, want main", got)
	}
	if got := testGitOutput(t, target, "config", "--local", "--get", "pi-managed.creationKey"); got != request.CreationKey {
		t.Fatalf("creation key = %q, want %q", got, request.CreationKey)
	}
	if got := testGitOutput(t, target, "remote"); got != "" {
		t.Fatalf("project creation configured remotes: %q", got)
	}

	request.ResumeExisting = true
	retried, err := createManagedProject(request)
	if err != nil {
		t.Fatalf("retry completed managed project: %v", err)
	}
	if !reflect.DeepEqual(retried, created) {
		t.Fatalf("completed retry changed result: %#v", retried)
	}
}

func TestCreateManagedProjectRejectsUnsafeOrForeignTargets(t *testing.T) {
	root := t.TempDir()
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)
	base := projectCreateRequest{CreationKey: "create-safe", RootKey: "projects", Workspace: "safe"}

	for _, request := range []projectCreateRequest{
		{CreationKey: "create-safe", RootKey: "foreign", Workspace: "safe"},
		{CreationKey: "bad key", RootKey: "projects", Workspace: "safe"},
		{CreationKey: "create-safe", RootKey: "projects", Workspace: "../escape"},
		{CreationKey: "create-safe", RootKey: "projects", Workspace: "nested/project"},
		{CreationKey: "create-safe", RootKey: "projects", Workspace: ".hidden"},
		{CreationKey: "create-safe", RootKey: "projects", Workspace: "bad name"},
	} {
		if _, err := createManagedProject(request); err == nil {
			t.Fatalf("unsafe request was accepted: %#v", request)
		}
	}

	occupied := filepath.Join(root, "occupied")
	if err := os.Mkdir(occupied, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(occupied, "keep.txt"), []byte("keep"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, resume := range []bool{false, true} {
		request := base
		request.Workspace = "occupied"
		request.ResumeExisting = resume
		if _, err := createManagedProject(request); err == nil {
			t.Fatalf("foreign target was accepted with resumeExisting=%t", resume)
		}
	}
	content, err := os.ReadFile(filepath.Join(occupied, "keep.txt"))
	if err != nil || string(content) != "keep" {
		t.Fatalf("foreign target was modified: %q, %v", content, err)
	}

	outside := t.TempDir()
	if err := os.Symlink(outside, filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	linkedRequest := base
	linkedRequest.Workspace = "linked"
	linkedRequest.ResumeExisting = true
	if _, err := createManagedProject(linkedRequest); err == nil {
		t.Fatal("symlinked project target was accepted")
	}

	linkedRoot := filepath.Join(t.TempDir(), "linked-root")
	if err := os.Symlink(root, linkedRoot); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(linkedRoot)+`}`)
	if _, err := createManagedProject(base); err == nil {
		t.Fatal("symlinked configured root was accepted")
	}
}

func TestCreateManagedProjectRecoversOnlyMatchingStagingState(t *testing.T) {
	for _, state := range []string{"empty", "marker", "initialized"} {
		t.Run(state, func(t *testing.T) {
			root := t.TempDir()
			t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)
			request := projectCreateRequest{CreationKey: "create-" + state, ResumeExisting: true, RootKey: "projects", Workspace: state}
			staging := projectStagingPath(root, request.CreationKey)
			if err := os.Mkdir(staging, 0o700); err != nil {
				t.Fatal(err)
			}
			if state == "marker" {
				if err := os.WriteFile(filepath.Join(staging, ".pi-managed-project-creation"), []byte(request.CreationKey+"\n"), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			if state == "initialized" {
				testGit(t, staging, "init", "-b", "main")
				testGit(t, staging, "config", "--local", "pi-managed.creationKey", request.CreationKey)
			}
			if _, err := createManagedProject(request); err != nil {
				t.Fatalf("recover %s staging state: %v", state, err)
			}
			if _, err := os.Stat(filepath.Join(root, state, ".git")); err != nil {
				t.Fatalf("recovered project is incomplete: %v", err)
			}
			if _, err := os.Lstat(staging); !os.IsNotExist(err) {
				t.Fatalf("staging path remained after recovery: %v", err)
			}
		})
	}
}

func TestCreateManagedProjectRejectsConflictingRecoveryState(t *testing.T) {
	root := t.TempDir()
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)
	request := projectCreateRequest{CreationKey: "create-conflict", ResumeExisting: true, RootKey: "projects", Workspace: "conflict"}
	staging := projectStagingPath(root, request.CreationKey)
	if err := os.Mkdir(staging, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(staging, "foreign.txt"), []byte("keep"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := createManagedProject(request); err == nil {
		t.Fatal("foreign staging state was accepted")
	}
	if content, err := os.ReadFile(filepath.Join(staging, "foreign.txt")); err != nil || string(content) != "keep" {
		t.Fatalf("foreign staging state was modified: %q, %v", content, err)
	}

	noRetry := projectCreateRequest{CreationKey: "create-no-retry", RootKey: "projects", Workspace: "no-retry"}
	if err := os.Mkdir(projectStagingPath(root, noRetry.CreationKey), 0o700); err != nil {
		t.Fatal(err)
	}
	if _, err := createManagedProject(noRetry); err == nil {
		t.Fatal("pre-existing staging state was accepted without resumeExisting")
	}

	wrongMarker := projectCreateRequest{CreationKey: "create-wrong-marker", ResumeExisting: true, RootKey: "projects", Workspace: "wrong-marker"}
	wrongMarkerStaging := projectStagingPath(root, wrongMarker.CreationKey)
	if err := os.Mkdir(wrongMarkerStaging, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(wrongMarkerStaging, ".pi-managed-project-creation"), []byte("another-key\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := createManagedProject(wrongMarker); err == nil {
		t.Fatal("mismatched creation marker was accepted")
	}

	symlinkRequest := projectCreateRequest{CreationKey: "create-symlink", ResumeExisting: true, RootKey: "projects", Workspace: "symlink"}
	symlinkStaging := projectStagingPath(root, symlinkRequest.CreationKey)
	if err := os.Mkdir(symlinkStaging, 0o700); err != nil {
		t.Fatal(err)
	}
	external := t.TempDir()
	if err := os.Mkdir(filepath.Join(external, ".git"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(external, ".git"), filepath.Join(symlinkStaging, ".git")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(symlinkStaging, ".pi-managed-project-creation"), []byte(symlinkRequest.CreationKey+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := createManagedProject(symlinkRequest); err == nil {
		t.Fatal("symlinked staging Git metadata was accepted")
	}
}

func TestCreateManagedProjectRejectsMismatchedCompletedRepository(t *testing.T) {
	root := t.TempDir()
	t.Setenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS", `{"projects":`+quoteJSON(root)+`}`)
	target := filepath.Join(root, "project")
	if err := os.Mkdir(target, 0o700); err != nil {
		t.Fatal(err)
	}
	testGit(t, target, "init", "-b", "other")
	testGit(t, target, "config", "--local", "pi-managed.creationKey", "wrong-key")
	request := projectCreateRequest{CreationKey: "expected-key", ResumeExisting: true, RootKey: "projects", Workspace: "project"}
	if _, err := createManagedProject(request); err == nil {
		t.Fatal("mismatched completed repository was accepted")
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

func projectStagingPath(root, creationKey string) string {
	digest := sha256.Sum256([]byte(creationKey))
	return filepath.Join(root, ".pi-managed-create-"+hex.EncodeToString(digest[:16]))
}

func testGit(t *testing.T, directory string, args ...string) {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v: %s", args, err, output)
	}
}

func testGitOutput(t *testing.T, directory string, args ...string) string {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	output, err := command.Output()
	if err != nil {
		t.Fatalf("git %v: %v", args, err)
	}
	return string(bytesTrimSpace(output))
}

func bytesTrimSpace(value []byte) []byte {
	start, end := 0, len(value)
	for start < end && (value[start] == ' ' || value[start] == '\n' || value[start] == '\r' || value[start] == '\t') {
		start++
	}
	for end > start && (value[end-1] == ' ' || value[end-1] == '\n' || value[end-1] == '\r' || value[end-1] == '\t') {
		end--
	}
	return value[start:end]
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
