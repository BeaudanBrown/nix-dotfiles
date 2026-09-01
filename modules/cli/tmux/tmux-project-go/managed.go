package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const managedWindowOption = "@managed_pi_conversation_id"

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
	args := []string{"-d", "-P", "-F", "#{window_id}|#{pane_id}", "-n", "coordinator", "-c", cwd}
	args = append(args, managedTmuxEnvironment(
		"PI_MANAGED_SESSION_LAUNCH_ROLE", "PI_MANAGED_SESSIONS_SOCKET", "PI_MANAGED_SESSION_CONVERSATION_ID",
		"PI_MANAGED_SESSION_CONCEPT", "PI_MANAGED_SESSION_BINDING_BOUNDARY_ENTRY_ID",
		"PI_MANAGED_SESSION_ATTACHMENT_NONCE", "PI_MANAGED_COORDINATOR_SESSION_FILE", "PI_MANAGED_COORDINATOR_CWD",
	)...)
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
	if _, err := tmux("set-option", "-w", "-t", observation.WindowID, managedWindowOption, request.ConversationID); err != nil {
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
		"PI_MANAGED_SESSION_ATTACHMENT_NONCE", "PI_MANAGED_PROJECT_SESSION_FILE",
	)...)
	args = append(args, "exec direnv exec "+shellQuote(resolved.Cwd)+" pi")
	output, err := tmux(args...)
	if err != nil {
		return err
	}
	observation, err = parseManagedWindowOutput(output)
	if err != nil {
		return err
	}
	if _, err := tmux("set-option", "-w", "-t", observation.WindowID, managedWindowOption, request.ConversationID); err != nil {
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
	}
	return writeManagedResult(struct {
		Cleared bool `json:"cleared"`
	}{Cleared: observation != nil})
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
