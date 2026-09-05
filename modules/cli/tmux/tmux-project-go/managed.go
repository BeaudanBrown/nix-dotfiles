package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

const (
	managedWindowOption  = "@managed_pi_conversation_id"
	managedConceptOption = "@managed_pi_concept"
)

type workspacePlacement struct {
	RootKey     string `json:"rootKey"`
	Workspace   string `json:"workspace"`
	RelativeCwd string `json:"relativeCwd"`
}

type resolvedWorkspace struct {
	workspacePlacement
	WorkspacePath string `json:"workspacePath"`
	Cwd           string `json:"cwd"`
}

type projectCreateRequest struct {
	CreationKey    string
	ResumeExisting bool
	RootKey        string
	Workspace      string
}

type projectCreateWireRequest struct {
	CreationKey    string `json:"creationKey"`
	ResumeExisting *bool  `json:"resumeExisting"`
	RootKey        string `json:"rootKey"`
	Workspace      string `json:"workspace"`
}

type managedWindowResult struct {
	ConversationID string `json:"conversationId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
	Role           string `json:"role"`
}

type managedProjectWindowResult struct {
	ConversationID string `json:"conversationId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	PaneID         string `json:"paneId"`
	Role           string `json:"role"`
	RootKey        string `json:"rootKey"`
	Workspace      string `json:"workspace"`
	RelativeCwd    string `json:"relativeCwd"`
}

type managedWindowIdentity struct {
	ConversationID string `json:"conversationId"`
	WindowID       string `json:"windowId,omitempty"`
	PaneID         string `json:"paneId,omitempty"`
}

type managedWindowObservation struct {
	WindowID string
	PaneID   string
}

func managed(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("tmux_project managed requires exactly one operation")
	}
	if err := requireManagedTmuxRuntime(); err != nil {
		return err
	}
	if args[0] != "legacy-window-preview" && args[0] != "legacy-window-cleanup" && os.Getenv("TMUX") != "" {
		return fmt.Errorf("managed lifecycle commands must not inherit an attached tmux target")
	}
	switch args[0] {
	case "workspace-list":
		var request struct{}
		if err := readManagedRequest(&request); err != nil {
			return err
		}
		roots, err := managedWorkspaceRoots()
		if err != nil {
			return err
		}
		type item struct {
			RootKey   string `json:"rootKey"`
			Workspace string `json:"workspace"`
		}
		var workspaces []item
		keys := make([]string, 0, len(roots))
		for key := range roots {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			entries, err := os.ReadDir(roots[key])
			if err != nil {
				return fmt.Errorf("list workspace root %s: %w", key, err)
			}
			for _, entry := range entries {
				if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") || !safeWorkspaceName(entry.Name()) {
					continue
				}
				workspaces = append(workspaces, item{RootKey: key, Workspace: entry.Name()})
			}
		}
		return writeManagedResult(struct {
			Workspaces []item `json:"workspaces"`
		}{Workspaces: workspaces})
	case "project-create":
		var wire projectCreateWireRequest
		if err := readManagedRequest(&wire); err != nil {
			return err
		}
		if wire.ResumeExisting == nil {
			return fmt.Errorf("managed project creation request is invalid")
		}
		request := projectCreateRequest{
			CreationKey: wire.CreationKey, ResumeExisting: *wire.ResumeExisting,
			RootKey: wire.RootKey, Workspace: wire.Workspace,
		}
		resolved, err := createManagedProject(request)
		if err != nil {
			return err
		}
		return writeManagedResult(resolved)
	case "workspace-resolve":
		var placement workspacePlacement
		if err := readManagedRequest(&placement); err != nil {
			return err
		}
		resolved, err := resolveManagedWorkspace(placement)
		if err != nil {
			return err
		}
		return writeManagedResult(resolved)
	case "root-ensure":
		var placement workspacePlacement
		if err := readManagedRequest(&placement); err != nil {
			return err
		}
		resolved, err := resolveManagedWorkspace(placement)
		if err != nil {
			return err
		}
		session, err := ensureProjectSession(resolved.WorkspacePath)
		if err != nil {
			return err
		}
		return writeManagedResult(struct {
			SessionName   string `json:"sessionName"`
			WorkspacePath string `json:"workspacePath"`
		}{SessionName: session, WorkspacePath: resolved.WorkspacePath})
	case "window-inspect":
		return managedWindowInspect()
	case "coordinator-ensure":
		return managedCoordinatorEnsure()
	case "window-create":
		return managedWindowCreate()
	case "window-terminate", "bridge-clear":
		return managedWindowMutation(args[0])
	case "legacy-window-preview":
		var request struct{}
		if err := readManagedRequest(&request); err != nil {
			return err
		}
		windows, err := legacyManagedWindows()
		if err != nil {
			return err
		}
		return writeManagedResult(struct {
			Windows []legacyManagedWindow `json:"windows"`
		}{Windows: windows})
	case "legacy-window-cleanup":
		var request struct {
			Confirmed *bool `json:"confirmed"`
		}
		if err := readManagedRequest(&request); err != nil {
			return err
		}
		if request.Confirmed == nil || !*request.Confirmed {
			return fmt.Errorf("legacy managed window cleanup requires explicit confirmation")
		}
		cleaned, err := cleanupLegacyManagedWindows()
		if err != nil {
			return err
		}
		return writeManagedResult(struct {
			Cleaned int `json:"cleaned"`
		}{Cleaned: cleaned})
	default:
		return fmt.Errorf("unknown managed operation %q", args[0])
	}
}

func managedWindowInspect() error {
	var request struct {
		ConversationID string `json:"conversationId"`
	}
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	if !validConversationID(request.ConversationID) {
		return fmt.Errorf("invalid managed conversation identity")
	}
	observation, err := findManagedWindow(request.ConversationID)
	if err != nil {
		return err
	}
	if observation == nil {
		return writeManagedResult(struct {
			ConversationID string `json:"conversationId"`
			Exists         bool   `json:"exists"`
		}{ConversationID: request.ConversationID, Exists: false})
	}
	sessionName, err := tmux("display-message", "-p", "-t", observation.WindowID, "#{session_name}")
	if err != nil {
		return err
	}
	return writeManagedResult(struct {
		ConversationID string `json:"conversationId"`
		Exists         bool   `json:"exists"`
		SessionName    string `json:"sessionName"`
		WindowID       string `json:"windowId"`
		PaneID         string `json:"paneId"`
	}{ConversationID: request.ConversationID, Exists: true, SessionName: sessionName,
		WindowID: observation.WindowID, PaneID: observation.PaneID})
}

func managedCoordinatorEnsure() error {
	var request struct {
		ConversationID string `json:"conversationId"`
	}
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	if !validConversationID(request.ConversationID) || request.ConversationID != os.Getenv("PI_MANAGED_SESSION_CONVERSATION_ID") {
		return fmt.Errorf("invalid coordinator conversation identity")
	}
	cwd, err := requiredManagedEnv("PI_MANAGED_COORDINATOR_CWD")
	if err != nil {
		return err
	}
	for _, name := range []string{
		"PI_MANAGED_SESSION_LAUNCH_ROLE", "PI_MANAGED_SESSIONS_SOCKET", "PI_MANAGED_SESSION_CONCEPT",
		"PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID", "PI_MANAGED_SESSION_ATTACHMENT_NONCE",
		"PI_MANAGED_COORDINATOR_SESSION_FILE",
	} {
		if _, err := requiredManagedEnv(name); err != nil {
			return err
		}
	}
	observation, err := findManagedWindow(request.ConversationID)
	if err != nil {
		return err
	}
	if observation != nil {
		return fmt.Errorf("coordinator window already exists; inspect before creating")
	}
	selectionEnvironment, err := managedSelectionEnvironment()
	if err != nil {
		return err
	}
	args := []string{"-d", "-P", "-F", "#{window_id}|#{pane_id}", "-n", "coordinator", "-c", cwd}
	args = append(args, managedTmuxEnvironment(
		"PI_MANAGED_SESSION_LAUNCH_ROLE", "PI_MANAGED_SESSIONS_SOCKET", "PI_MANAGED_SESSION_CONVERSATION_ID",
		"PI_MANAGED_SESSION_CONCEPT", "PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID",
		"PI_MANAGED_SESSION_ATTACHMENT_NONCE", "PI_MANAGED_COORDINATOR_SESSION_FILE", "PI_MANAGED_COORDINATOR_CWD",
	)...)
	args = append(args, selectionEnvironment...)
	command := "exec direnv exec " + shellQuote(cwd) + " pi"
	var output string
	if tmuxOk("has-session", "-t", "=default") {
		output, err = tmux(append([]string{"new-window"}, append(args, "-t", "=default:", command)...)...)
	} else {
		output, err = tmux(append([]string{"new-session"}, append(args, "-s", "default", command)...)...)
	}
	if err != nil {
		return err
	}
	observation, err = parseManagedWindowOutput(output)
	if err != nil {
		return err
	}
	if err := markManagedWindow(observation.WindowID, request.ConversationID); err != nil {
		return err
	}
	return writeManagedResult(managedWindowResult{
		ConversationID: request.ConversationID, SessionName: "default", WindowID: observation.WindowID,
		PaneID: observation.PaneID, Role: "coordinator",
	})
}

func managedWindowCreate() error {
	var request struct {
		ConversationID string             `json:"conversationId"`
		Placement      workspacePlacement `json:"placement"`
	}
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	if !validConversationID(request.ConversationID) || request.ConversationID != os.Getenv("PI_MANAGED_SESSION_CONVERSATION_ID") {
		return fmt.Errorf("invalid project conversation identity")
	}
	for _, name := range []string{
		"PI_MANAGED_SESSION_LAUNCH_ROLE", "PI_MANAGED_SESSIONS_SOCKET", "PI_MANAGED_SESSION_CONCEPT",
		"PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID", "PI_MANAGED_SESSION_ATTACHMENT_NONCE", "PI_MANAGED_PROJECT_SESSION_FILE",
	} {
		if _, err := requiredManagedEnv(name); err != nil {
			return err
		}
	}
	resolved, err := resolveManagedWorkspace(request.Placement)
	if err != nil {
		return err
	}
	if err := validateManagedWorkspacePath(resolved.WorkspacePath); err != nil {
		return err
	}
	selectionEnvironment, err := managedSelectionEnvironment()
	if err != nil {
		return err
	}
	session, err := ensureProjectSession(resolved.WorkspacePath)
	if err != nil {
		return err
	}
	observation, err := findManagedWindow(request.ConversationID)
	if err != nil {
		return err
	}
	if observation != nil {
		return fmt.Errorf("managed project window already exists; inspect before creating")
	}
	args := []string{"new-window", "-d", "-P", "-F", "#{window_id}|#{pane_id}", "-t", "=" + session + ":",
		"-n", "pi-" + request.ConversationID[len(request.ConversationID)-8:], "-c", resolved.Cwd}
	args = append(args, managedTmuxEnvironment(
		"PI_MANAGED_SESSION_LAUNCH_ROLE", "PI_MANAGED_SESSIONS_SOCKET", "PI_MANAGED_SESSION_CONVERSATION_ID",
		"PI_MANAGED_SESSION_CONCEPT", "PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID",
		"PI_MANAGED_SESSION_ATTACHMENT_NONCE", "PI_MANAGED_PROJECT_SESSION_FILE", "PI_MANAGED_SESSION_WORKSPACE_PATH",
	)...)
	args = append(args, selectionEnvironment...)
	args = append(args, "exec direnv exec "+shellQuote(resolved.Cwd)+" pi")
	output, err := tmux(args...)
	if err != nil {
		return err
	}
	observation, err = parseManagedWindowOutput(output)
	if err != nil {
		return err
	}
	if err := markManagedWindow(observation.WindowID, request.ConversationID); err != nil {
		return err
	}
	return writeManagedResult(managedProjectWindowResult{
		ConversationID: request.ConversationID, SessionName: session, WindowID: observation.WindowID, PaneID: observation.PaneID,
		Role: "conversation", RootKey: resolved.RootKey, Workspace: resolved.Workspace,
		RelativeCwd: resolved.RelativeCwd,
	})
}

func managedWindowMutation(operation string) error {
	var request managedWindowIdentity
	if err := readManagedRequest(&request); err != nil {
		return err
	}
	if !validConversationID(request.ConversationID) {
		return fmt.Errorf("invalid managed conversation identity")
	}
	observation, err := findManagedWindow(request.ConversationID)
	if err != nil {
		return err
	}
	if observation != nil && request.WindowID != "" && (observation.WindowID != request.WindowID || observation.PaneID != request.PaneID) {
		return fmt.Errorf("managed window identity mismatch")
	}
	if operation == "window-terminate" {
		if observation == nil {
			return fmt.Errorf("managed window was not found")
		}
		if _, err := tmux("kill-window", "-t", observation.WindowID); err != nil {
			return err
		}
		return writeManagedResult(struct {
			Terminated bool `json:"terminated"`
		}{Terminated: true})
	}
	if observation != nil {
		if _, err := tmux("set-option", "-w", "-u", "-t", observation.WindowID, managedWindowOption); err != nil {
			return err
		}
		if _, err := tmux("set-option", "-w", "-u", "-t", observation.WindowID, managedConceptOption); err != nil {
			return err
		}
	}
	return writeManagedResult(struct {
		Cleared bool `json:"cleared"`
	}{Cleared: observation != nil})
}

func createManagedProject(request projectCreateRequest) (resolvedWorkspace, error) {
	if !safeIdentifier(request.CreationKey) || !safeProjectWorkspaceName(request.Workspace) {
		return resolvedWorkspace{}, fmt.Errorf("managed project creation request is invalid")
	}
	roots, err := managedWorkspaceRoots()
	if err != nil {
		return resolvedWorkspace{}, err
	}
	root, ok := roots[request.RootKey]
	if !ok {
		return resolvedWorkspace{}, fmt.Errorf("managed project creation root is invalid")
	}
	target := filepath.Join(root, request.Workspace)
	if _, err := os.Lstat(target); err == nil {
		if !request.ResumeExisting {
			return resolvedWorkspace{}, fmt.Errorf("managed project target already exists")
		}
		if err := verifyManagedProject(target, request.CreationKey); err != nil {
			return resolvedWorkspace{}, err
		}
		return createdWorkspaceResult(request, target), nil
	} else if !os.IsNotExist(err) {
		return resolvedWorkspace{}, fmt.Errorf("inspect managed project target: %w", err)
	}

	digest := sha256.Sum256([]byte(request.CreationKey))
	staging := filepath.Join(root, ".pi-managed-create-"+hex.EncodeToString(digest[:16]))
	marker := filepath.Join(staging, ".pi-managed-project-creation")
	if _, err := os.Lstat(staging); os.IsNotExist(err) {
		if err := os.Mkdir(staging, 0o700); err != nil {
			return resolvedWorkspace{}, fmt.Errorf("create managed project staging directory: %w", err)
		}
		if err := writeProjectCreationMarker(marker, request.CreationKey); err != nil {
			return resolvedWorkspace{}, err
		}
	} else if err != nil {
		return resolvedWorkspace{}, fmt.Errorf("inspect managed project staging directory: %w", err)
	} else {
		if !request.ResumeExisting {
			return resolvedWorkspace{}, fmt.Errorf("managed project staging state already exists")
		}
		if err := recoverProjectCreationStaging(staging, marker, request.CreationKey); err != nil {
			return resolvedWorkspace{}, err
		}
	}

	if err := rejectUnsafeGitMetadata(staging); err != nil {
		return resolvedWorkspace{}, err
	}
	if err := runManagedGit(staging, "init", "-b", "main"); err != nil {
		return resolvedWorkspace{}, fmt.Errorf("initialize managed project Git repository: %w", err)
	}
	if err := verifyRealOwnedDirectory(filepath.Join(staging, ".git"), "managed project Git metadata"); err != nil {
		return resolvedWorkspace{}, err
	}
	if err := verifyGitTopLevel(staging); err != nil {
		return resolvedWorkspace{}, err
	}
	branch, err := managedGitOutput(staging, "symbolic-ref", "--short", "HEAD")
	if err != nil || branch != "main" {
		return resolvedWorkspace{}, fmt.Errorf("managed project must use the main branch")
	}
	if err := runManagedGit(staging, "config", "--local", "pi-managed.creationKey", request.CreationKey); err != nil {
		return resolvedWorkspace{}, fmt.Errorf("record managed project creation identity: %w", err)
	}
	if err := os.Remove(marker); err != nil && !os.IsNotExist(err) {
		return resolvedWorkspace{}, fmt.Errorf("remove managed project creation marker: %w", err)
	}
	if _, err := os.Lstat(target); err == nil || !os.IsNotExist(err) {
		return resolvedWorkspace{}, fmt.Errorf("managed project target appeared during creation")
	}
	if err := os.Rename(staging, target); err != nil {
		return resolvedWorkspace{}, fmt.Errorf("publish managed project: %w", err)
	}
	if err := verifyManagedProject(target, request.CreationKey); err != nil {
		return resolvedWorkspace{}, err
	}
	return createdWorkspaceResult(request, target), nil
}

func createdWorkspaceResult(request projectCreateRequest, target string) resolvedWorkspace {
	return resolvedWorkspace{
		workspacePlacement: workspacePlacement{RootKey: request.RootKey, Workspace: request.Workspace, RelativeCwd: ""},
		WorkspacePath:      target,
		Cwd:                target,
	}
}

func recoverProjectCreationStaging(staging, marker, creationKey string) error {
	if err := verifyRealOwnedDirectory(staging, "managed project staging directory"); err != nil {
		return err
	}
	entries, err := os.ReadDir(staging)
	if err != nil {
		return fmt.Errorf("read managed project staging directory: %w", err)
	}
	if len(entries) == 0 {
		return writeProjectCreationMarker(marker, creationKey)
	}
	allowed := map[string]bool{".git": true, ".pi-managed-project-creation": true}
	for _, entry := range entries {
		if !allowed[entry.Name()] {
			return fmt.Errorf("managed project staging directory contains foreign state")
		}
	}
	if _, err := os.Lstat(marker); err == nil {
		info, err := os.Lstat(marker)
		if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || !ownedByCurrentUser(info) || info.Mode().Perm()&0o077 != 0 || info.Size() > 129 {
			return fmt.Errorf("managed project creation marker is unsafe")
		}
		content, err := os.ReadFile(marker)
		if err != nil || string(content) != creationKey+"\n" {
			return fmt.Errorf("managed project creation marker does not match")
		}
		return nil
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("inspect managed project creation marker: %w", err)
	}
	if len(entries) != 1 || entries[0].Name() != ".git" {
		return fmt.Errorf("managed project staging directory is not recoverable")
	}
	if err := verifyManagedProject(staging, creationKey); err != nil {
		return fmt.Errorf("managed project staging identity does not match: %w", err)
	}
	return nil
}

func writeProjectCreationMarker(marker, creationKey string) error {
	file, err := os.OpenFile(marker, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return fmt.Errorf("write managed project creation marker: %w", err)
	}
	if _, err := file.WriteString(creationKey + "\n"); err != nil {
		_ = file.Close()
		return fmt.Errorf("write managed project creation marker: %w", err)
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return fmt.Errorf("sync managed project creation marker: %w", err)
	}
	if err := file.Close(); err != nil {
		return fmt.Errorf("close managed project creation marker: %w", err)
	}
	return nil
}

func verifyManagedProject(path, creationKey string) error {
	if err := verifyRealOwnedDirectory(path, "managed project"); err != nil {
		return err
	}
	if err := verifyRealOwnedDirectory(filepath.Join(path, ".git"), "managed project Git metadata"); err != nil {
		return err
	}
	if err := verifyGitTopLevel(path); err != nil {
		return err
	}
	branch, err := managedGitOutput(path, "symbolic-ref", "--short", "HEAD")
	if err != nil || branch != "main" {
		return fmt.Errorf("managed project must use the main branch")
	}
	storedKey, err := managedGitOutput(path, "config", "--local", "--get", "pi-managed.creationKey")
	if err != nil || storedKey != creationKey {
		return fmt.Errorf("managed project creation identity does not match")
	}
	return nil
}

func verifyGitTopLevel(path string) error {
	topLevel, err := managedGitOutput(path, "rev-parse", "--show-toplevel")
	if err != nil {
		return fmt.Errorf("resolve managed project Git top level: %w", err)
	}
	canonical, err := filepath.EvalSymlinks(topLevel)
	if err != nil || canonical != path {
		return fmt.Errorf("managed project Git repository escaped its directory")
	}
	return nil
}

func rejectUnsafeGitMetadata(path string) error {
	metadata := filepath.Join(path, ".git")
	info, err := os.Lstat(metadata)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect managed project Git metadata: %w", err)
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || !ownedByCurrentUser(info) {
		return fmt.Errorf("managed project Git metadata is unsafe")
	}
	return nil
}

func verifyRealOwnedDirectory(path, description string) error {
	info, err := os.Lstat(path)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || !ownedByCurrentUser(info) {
		return fmt.Errorf("%s must be a real user-owned directory", description)
	}
	return nil
}

func ownedByCurrentUser(info os.FileInfo) bool {
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && stat.Uid == uint32(os.Getuid())
}

func runManagedGit(directory string, args ...string) error {
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	command.Stdout = io.Discard
	command.Stderr = io.Discard
	return command.Run()
}

func managedGitOutput(directory string, args ...string) (string, error) {
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	command.Stderr = io.Discard
	output, err := command.Output()
	if err != nil {
		return "", err
	}
	if len(output) > 4096 {
		return "", fmt.Errorf("git output exceeded its bound")
	}
	return strings.TrimSpace(string(output)), nil
}

func managedWorkspaceRoots() (map[string]string, error) {
	raw := os.Getenv("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS")
	if raw == "" {
		return nil, fmt.Errorf("PI_MANAGED_SESSIONS_WORKSPACE_ROOTS is required")
	}
	var configured map[string]string
	if err := json.Unmarshal([]byte(raw), &configured); err != nil || len(configured) == 0 {
		return nil, fmt.Errorf("managed workspace roots are malformed")
	}
	resolved := make(map[string]string, len(configured))
	for key, path := range configured {
		if !safeIdentifier(key) || !filepath.IsAbs(path) {
			return nil, fmt.Errorf("managed workspace root %q is invalid", key)
		}
		if err := verifyRealOwnedDirectory(path, "managed workspace root"); err != nil {
			return nil, fmt.Errorf("workspace root %s is unsafe: %w", key, err)
		}
		canonical, err := filepath.EvalSymlinks(path)
		if err != nil {
			return nil, fmt.Errorf("resolve workspace root %s: %w", key, err)
		}
		info, err := os.Stat(canonical)
		if err != nil || !info.IsDir() {
			return nil, fmt.Errorf("workspace root %s is not a directory", key)
		}
		resolved[key] = canonical
	}
	return resolved, nil
}

func resolveManagedWorkspace(placement workspacePlacement) (resolvedWorkspace, error) {
	roots, err := managedWorkspaceRoots()
	if err != nil {
		return resolvedWorkspace{}, err
	}
	root, ok := roots[placement.RootKey]
	if !ok || !safeWorkspaceName(placement.Workspace) || strings.HasPrefix(placement.Workspace, ".") {
		return resolvedWorkspace{}, fmt.Errorf("managed workspace placement is invalid")
	}
	if !safeRelativePath(placement.RelativeCwd) {
		return resolvedWorkspace{}, fmt.Errorf("managed relative cwd is invalid")
	}
	candidate := filepath.Join(root, placement.Workspace)
	metadata, err := os.Lstat(candidate)
	if err != nil || !metadata.IsDir() || metadata.Mode()&os.ModeSymlink != 0 {
		return resolvedWorkspace{}, fmt.Errorf("managed workspace must be a real immediate-child directory")
	}
	workspacePath, err := filepath.EvalSymlinks(candidate)
	if err != nil || filepath.Dir(workspacePath) != root {
		return resolvedWorkspace{}, fmt.Errorf("managed workspace escaped its configured root")
	}
	cwdCandidate := workspacePath
	if placement.RelativeCwd != "" {
		cwdCandidate = filepath.Join(workspacePath, filepath.FromSlash(placement.RelativeCwd))
	}
	cwd, err := filepath.EvalSymlinks(cwdCandidate)
	if err != nil || (cwd != workspacePath && !strings.HasPrefix(cwd, workspacePath+string(os.PathSeparator))) {
		return resolvedWorkspace{}, fmt.Errorf("managed cwd escaped its workspace")
	}
	info, err := os.Stat(cwd)
	if err != nil || !info.IsDir() {
		return resolvedWorkspace{}, fmt.Errorf("managed cwd is not a directory")
	}
	return resolvedWorkspace{workspacePlacement: placement, WorkspacePath: workspacePath, Cwd: cwd}, nil
}

type legacyManagedWindow struct {
	ConversationID string `json:"conversationId"`
	SessionName    string `json:"sessionName"`
	WindowID       string `json:"windowId"`
	WindowName     string `json:"windowName"`
}

func legacyTmuxSocket() string {
	return filepath.Join("/tmp", fmt.Sprintf("tmux-%d", os.Getuid()), "default")
}

func legacyManagedWindows() ([]legacyManagedWindow, error) {
	socket := legacyTmuxSocket()
	info, err := os.Lstat(socket)
	if os.IsNotExist(err) {
		return []legacyManagedWindow{}, nil
	}
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return nil, fmt.Errorf("legacy tmux socket is not a socket")
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || stat.Uid != uint32(os.Getuid()) {
		return nil, fmt.Errorf("legacy tmux socket is not owned by the managed user")
	}
	output, err := tmuxAt(socket, "list-windows", "-a", "-F", "#{session_name}|#{window_id}|#{window_name}|#{@managed_pi_conversation_id}")
	if err != nil {
		return nil, err
	}
	return parseLegacyManagedWindows(output), nil
}

func parseLegacyManagedWindows(output string) []legacyManagedWindow {
	windows := []legacyManagedWindow{}
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "|", 4)
		if len(parts) != 4 || !validConversationID(parts[3]) || !strings.HasPrefix(parts[1], "@") {
			continue
		}
		windows = append(windows, legacyManagedWindow{ConversationID: parts[3], SessionName: parts[0], WindowID: parts[1], WindowName: parts[2]})
	}
	return windows
}

func cleanupLegacyManagedWindows() (int, error) {
	if err := requireManagedRelayStopped(); err != nil {
		return 0, err
	}
	windows, err := legacyManagedWindows()
	if err != nil {
		return 0, err
	}
	for _, window := range windows {
		if _, err := tmuxAt(legacyTmuxSocket(), "kill-window", "-t", window.WindowID); err != nil {
			return 0, err
		}
	}
	remaining, err := legacyManagedWindows()
	if err != nil {
		return 0, err
	}
	if len(remaining) != 0 {
		return 0, fmt.Errorf("legacy managed windows remain after cleanup")
	}
	return len(windows), nil
}

func findManagedWindow(conversationID string) (*managedWindowObservation, error) {
	output, err := tmux("list-windows", "-a", "-F", "#{window_id}|#{pane_id}|#{@managed_pi_conversation_id}")
	if err != nil {
		if !tmuxOk("list-sessions") {
			return nil, nil
		}
		return nil, err
	}
	var found *managedWindowObservation
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "|", 3)
		if len(parts) != 3 || parts[2] != conversationID {
			continue
		}
		if found != nil {
			return nil, fmt.Errorf("managed conversation has multiple tmux windows")
		}
		found = &managedWindowObservation{WindowID: parts[0], PaneID: parts[1]}
	}
	return found, nil
}

func parseManagedWindowOutput(output string) (*managedWindowObservation, error) {
	parts := strings.Split(strings.TrimSpace(output), "|")
	if len(parts) != 2 || !strings.HasPrefix(parts[0], "@") || !strings.HasPrefix(parts[1], "%") {
		return nil, fmt.Errorf("tmux returned an invalid managed window identity")
	}
	return &managedWindowObservation{WindowID: parts[0], PaneID: parts[1]}, nil
}

func requireManagedRelayStopped() error {
	runtime, err := requiredManagedEnv("XDG_RUNTIME_DIR")
	if err != nil {
		return err
	}
	connection, err := net.DialTimeout("unix", filepath.Join(runtime, "pi-managed-sessions", "relay.sock"), 250*time.Millisecond)
	if err == nil {
		_ = connection.Close()
		return fmt.Errorf("managed relay must be stopped before legacy window cleanup")
	}
	return nil
}

func requireManagedTmuxRuntime() error {
	runtime, err := requiredManagedEnv("XDG_RUNTIME_DIR")
	if err != nil {
		return err
	}
	if !filepath.IsAbs(runtime) || filepath.Clean(runtime) != runtime {
		return fmt.Errorf("XDG_RUNTIME_DIR must be a canonical absolute path")
	}
	if os.Getenv("TMUX_TMPDIR") != runtime {
		return fmt.Errorf("managed tmux commands require TMUX_TMPDIR to equal XDG_RUNTIME_DIR")
	}
	return nil
}

func validateManagedWorkspacePath(resolved string) error {
	supplied, err := requiredManagedEnv("PI_MANAGED_SESSION_WORKSPACE_PATH")
	if err != nil {
		return err
	}
	if supplied != resolved {
		return fmt.Errorf("managed workspace path does not match host resolution")
	}
	return nil
}

func managedSelectionEnvironment() ([]string, error) {
	var values []string
	if model := os.Getenv("PI_MANAGED_SESSION_MODEL"); model != "" {
		if len(model) > 256 || strings.IndexFunc(model, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 {
			return nil, fmt.Errorf("PI_MANAGED_SESSION_MODEL is invalid")
		}
		values = append(values, "-e", "PI_MANAGED_SESSION_MODEL="+model)
	}
	if thinking := os.Getenv("PI_MANAGED_SESSION_THINKING"); thinking != "" {
		supported := map[string]bool{"off": true, "minimal": true, "low": true, "medium": true, "high": true, "xhigh": true, "max": true}
		if !supported[thinking] {
			return nil, fmt.Errorf("PI_MANAGED_SESSION_THINKING is invalid")
		}
		values = append(values, "-e", "PI_MANAGED_SESSION_THINKING="+thinking)
	}
	return values, nil
}

func markManagedWindow(windowID, conversationID string) error {
	if _, err := tmux("set-option", "-w", "-t", windowID, managedWindowOption, conversationID); err != nil {
		return err
	}
	concept := strings.TrimSpace(os.Getenv("PI_MANAGED_SESSION_CONCEPT"))
	if concept == "" || len(concept) > 128 || strings.IndexFunc(concept, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0 {
		concept = "managed Pi " + conversationID[len(conversationID)-8:]
	}
	_, err := tmux("set-option", "-w", "-t", windowID, managedConceptOption, concept)
	return err
}

func managedTmuxEnvironment(names ...string) []string {
	values := []string{"-e", "PATH=" + os.Getenv("PATH"), "-e", "HOME=" + os.Getenv("HOME"),
		"-e", "DIRENV_CONFIG=" + os.Getenv("DIRENV_CONFIG"), "-e", "PI_CODING_AGENT_DIR=" + os.Getenv("PI_CODING_AGENT_DIR")}
	for _, name := range names {
		values = append(values, "-e", name+"="+os.Getenv(name))
	}
	return values
}

func readManagedRequest(target any) error {
	decoder := json.NewDecoder(io.LimitReader(os.Stdin, 64*1024+1))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("invalid managed request: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return fmt.Errorf("managed request must contain exactly one JSON object")
	}
	return nil
}

func writeManagedResult(value any) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	return encoder.Encode(value)
}

func requiredManagedEnv(name string) (string, error) {
	value := os.Getenv(name)
	if value == "" {
		return "", fmt.Errorf("%s is required", name)
	}
	return value, nil
}

func safeIdentifier(value string) bool {
	if value == "" || len(value) > 128 {
		return false
	}
	for index, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') ||
			(index > 0 && (r == '.' || r == '_' || r == ':' || r == '-')) {
			continue
		}
		return false
	}
	return true
}

func safeProjectWorkspaceName(value string) bool {
	if value == "" || len(value) > 128 {
		return false
	}
	for index, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') ||
			(index > 0 && (r == '.' || r == '_' || r == '-')) {
			continue
		}
		return false
	}
	return true
}

func safeWorkspaceName(value string) bool {
	if value == "" || value == "." || value == ".." || len(value) > 128 || strings.ContainsAny(value, "/\\") {
		return false
	}
	for _, r := range value {
		if r < 0x20 || r == 0x7f {
			return false
		}
	}
	return true
}

func safeRelativePath(value string) bool {
	if value == "" {
		return true
	}
	if filepath.IsAbs(value) || strings.Contains(value, "\\") {
		return false
	}
	for _, segment := range strings.Split(value, "/") {
		if segment == "" || segment == "." || segment == ".." {
			return false
		}
		for _, r := range segment {
			if r < 0x20 || r == 0x7f {
				return false
			}
		}
	}
	return true
}

func validConversationID(value string) bool {
	if len(value) != len("conv_")+32 || !strings.HasPrefix(value, "conv_") {
		return false
	}
	for _, r := range value[len("conv_"):] {
		if !((r >= '0' && r <= '9') || (r >= 'a' && r <= 'f')) {
			return false
		}
	}
	return true
}
