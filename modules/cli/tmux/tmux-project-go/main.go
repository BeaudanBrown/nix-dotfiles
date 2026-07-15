package main

import (
	"bufio"
	"bytes"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type Session struct {
	Name, Root, Parent, Role, Group, PopupOwner, PopupRoot string
}

const (
	roleRoot       = "root"
	roleGlobalTool = "global-tool"
	roleSatellite  = "satellite"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "launcher":
		err = launcher(arg(2))
	case "launcher-popup":
		err = launcherPopup(arg(2))
	case "candidates":
		err = printCandidates()
	case "switch":
		if len(os.Args) < 3 {
			usage()
		}
		err = switchProject(os.Args[2], arg(3))
	case "scratch":
		err = openGlobalPopup("scratch", arg(2))
	case "scratch-new-window":
		err = openGlobalCommandPopup("scratch", arg(2), "", false, true)
	case "build":
		err = openSatellitePopup("build", arg(2))
	case "rebuild":
		err = openSatelliteCommandPopup("rebuild", arg(2), "", arg(3), false, false)
	case "rebuild-run":
		err = openSatelliteCommandPopup("rebuild", arg(2), arg(3), "", true, false)
	case "llm":
		err = openGlobalCommandPopup("LLM", arg(2), "LLM", false, false)
	case "obsidian":
		err = openGlobalCommandPopup("obsidian", arg(2), "mkdir -p ~/documents/vault/main && cd ~/documents/vault/main && nvim -O ~/documents/vault/main/triage.md", false, false)
	case "toggle-last-popup":
		err = toggleLastPopup(arg(2))
	case "note-root-focus":
		err = noteRootFocus(arg(2), arg(3))
	case "session-closed":
		if len(os.Args) < 3 {
			os.Exit(0)
		}
		err = sessionClosed(os.Args[2])
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "tmux_project <launcher|launcher-popup|candidates|switch|scratch|scratch-new-window|build|rebuild|rebuild-run|llm|obsidian|toggle-last-popup|note-root-focus|session-closed>")
	os.Exit(1)
}

func arg(i int) string {
	if len(os.Args) > i {
		return os.Args[i]
	}
	return ""
}

func tmux(args ...string) (string, error) {
	cmd := exec.Command("tmux", args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	err := cmd.Run()
	return strings.TrimRight(out.String(), "\n"), err
}

func tmuxOk(args ...string) bool { _, err := tmux(args...); return err == nil }

func clientName(client string) (string, error) {
	if client != "" {
		return client, nil
	}
	if v := os.Getenv("TMUX_PROJECT_CLIENT"); v != "" {
		return v, nil
	}
	return tmux("display-message", "-p", "#{client_name}")
}

func currentSession(client string) (string, error) {
	if client != "" {
		return tmux("display-message", "-p", "-c", client, "#{session_name}")
	}
	return tmux("display-message", "-p", "#{session_name}")
}

func sessionOption(session, key string) string {
	out, err := tmux("show-option", "-v", "-t", session, key)
	if err != nil {
		return ""
	}
	return out
}

func setSessionOption(session, key, value string) {
	_, _ = tmux("set-option", "-t", session, key, value)
}

func globalOption(key string) string {
	out, err := tmux("show-option", "-gqv", key)
	if err != nil {
		return ""
	}
	return out
}

func setGlobalOption(key, value string) {
	_, _ = tmux("set-option", "-g", key, value)
}

func allSessions() ([]Session, error) {
	format := strings.Join([]string{
		"#{session_name}", "#{@project_root}", "#{@project_parent}", "#{@project_role}",
		"#{@project_group}", "#{@project_popup_owner}", "#{@project_popup_root}",
	}, "\t")
	out, err := tmux("list-sessions", "-F", format)
	if err != nil {
		return nil, err
	}
	var sessions []Session
	s := bufio.NewScanner(strings.NewReader(out))
	for s.Scan() {
		parts := strings.Split(s.Text(), "\t")
		for len(parts) < 7 {
			parts = append(parts, "")
		}
		sessions = append(sessions, Session{parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]})
	}
	return sessions, nil
}

func isRoot(s Session) bool {
	return s.Role == roleRoot
}

func sessionByName(name string) Session {
	sessions, _ := allSessions()
	for _, s := range sessions {
		if s.Name == name {
			return s
		}
	}
	return Session{Name: name}
}

func sessionRoot(session string) string {
	s := sessionByName(session)
	if s.Root != "" {
		return s.Root
	}
	if out, err := tmux("display-message", "-p", "-t", "="+session+":", "#{pane_current_path}"); err == nil && out != "" {
		return out
	}
	h, _ := os.UserHomeDir()
	return h
}

func rootForSession(session string) string {
	s := sessionByName(session)
	if s.Role == roleSatellite && s.Parent != "" {
		return s.Parent
	}
	if s.Role == roleGlobalTool && s.PopupRoot != "" {
		return s.PopupRoot
	}
	if s.Parent != "" {
		return s.Parent
	}
	return session
}

func markRoot(session, root string) {
	setSessionOption(session, "@project_role", roleRoot)
	setSessionOption(session, "@project_root", root)
}

func sanitize(name string) string {
	var b strings.Builder
	for _, r := range name {
		if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' || r == '.' || r == '-' {
			b.WriteRune(r)
		} else {
			b.WriteByte('_')
		}
	}
	out := strings.Trim(b.String(), "_")
	if out == "" {
		return "project"
	}
	return out
}

func sessionForPath(path string) string {
	base := sanitize(filepath.Base(path))
	if tmuxOk("has-session", "-t", "="+base) {
		if sessionOption(base, "@project_root") == path {
			return base
		}
		h := sha1.Sum([]byte(path))
		return base + "-" + hex.EncodeToString(h[:])[:8]
	}
	return base
}

func ensureProjectSession(path string) (string, error) {
	session := sessionForPath(path)
	if !tmuxOk("has-session", "-t", "="+session) {
		if _, err := tmux("new-session", "-d", "-s", session, "-c", path); err != nil {
			return "", err
		}
	}
	markRoot(session, path)
	return session, nil
}

func switchTo(session, client string) error {
	var err error
	if client != "" {
		_, err = tmux("switch-client", "-c", client, "-t", "="+session)
	} else {
		_, err = tmux("switch-client", "-t", "="+session)
	}
	if err == nil {
		maybeCleanupDefault(session)
	}
	return err
}

func maybeCleanupDefault(activeRoot string) {
	if activeRoot == "" || activeRoot == "default" || !tmuxOk("has-session", "-t", "=default") {
		return
	}
	if !isRoot(sessionByName(activeRoot)) {
		return
	}
	if defaultHasClients() || !defaultIsIdle() {
		return
	}
	_, _ = tmux("kill-session", "-t", "=default")
}

func defaultHasClients() bool {
	out, err := tmux("list-clients", "-F", "#{session_name}")
	if err != nil {
		return false
	}
	s := bufio.NewScanner(strings.NewReader(out))
	for s.Scan() {
		if s.Text() == "default" {
			return true
		}
	}
	return false
}

func defaultIsIdle() bool {
	windows, err := tmux("list-windows", "-t", "=default", "-F", "#{window_id}")
	if err != nil || countLines(windows) != 1 {
		return false
	}
	panes, err := tmux("list-panes", "-t", "=default:", "-F", "#{pane_current_command}\t#{pane_current_path}")
	if err != nil || countLines(panes) != 1 {
		return false
	}
	parts := strings.SplitN(panes, "\t", 2)
	if len(parts) != 2 || !isShellCommand(parts[0]) {
		return false
	}
	home, _ := os.UserHomeDir()
	return parts[1] == home
}

func countLines(s string) int {
	if s == "" {
		return 0
	}
	return len(strings.Split(s, "\n"))
}

func isShellCommand(command string) bool {
	switch filepath.Base(command) {
	case "sh", "bash", "zsh", "fish":
		return true
	default:
		return false
	}
}

func rootSessions() []Session {
	sessions, _ := allSessions()
	var roots []Session
	for _, s := range sessions {
		if isRoot(s) {
			roots = append(roots, s)
		}
	}
	return roots
}

func homeRelative(path string) string {
	h, _ := os.UserHomeDir()
	if path == h {
		return "~"
	}
	if strings.HasPrefix(path, h+string(os.PathSeparator)) {
		return "~/" + strings.TrimPrefix(path, h+string(os.PathSeparator))
	}
	return path
}

func projectPaths() []string {
	h, _ := os.UserHomeDir()
	roots := []string{filepath.Join(h, "documents"), filepath.Join(h, "monash")}
	seen := map[string]bool{}
	var paths []string
	for _, root := range roots {
		if st, err := os.Stat(root); err != nil || !st.IsDir() {
			continue
		}
		cmd := exec.Command("fd", "-H", "-t", "d", "^\\.git$", root, "--max-depth", "6", "--absolute-path", "--exclude", "node_modules", "--exclude", ".direnv", "--exclude", "result", "--exclude", ".venv", "--exclude", "venv")
		out, err := cmd.Output()
		if err != nil {
			continue
		}
		s := bufio.NewScanner(bytes.NewReader(out))
		for s.Scan() {
			gitDir := strings.TrimRight(s.Text(), string(os.PathSeparator))
			dir := filepath.Dir(gitDir)
			git := exec.Command("git", "-C", dir, "rev-parse", "--show-toplevel")
			top, err := git.Output()
			if err != nil {
				continue
			}
			path := strings.TrimSpace(string(top))
			if path != "" && !seen[path] {
				seen[path] = true
				paths = append(paths, path)
			}
		}
	}
	return paths
}

type Candidate struct {
	Kind, Value, Name, Path string
	Score                   float64
}

func candidates() []Candidate {
	seenRoots := map[string]bool{}
	var cs []Candidate
	for _, s := range rootSessions() {
		root := s.Root
		if root == "" {
			root = sessionRoot(s.Name)
		}
		seenRoots[root] = true
		name := s.Name
		if s.Name != "default" && root != "" {
			name = filepath.Base(root)
		}
		cs = append(cs, Candidate{"session", s.Name, name, homeRelative(root), autojumpScore(root)})
	}
	for _, path := range projectPaths() {
		if seenRoots[path] {
			continue
		}
		cs = append(cs, Candidate{"path", path, filepath.Base(path), homeRelative(path), autojumpScore(path)})
	}
	sort.SliceStable(cs, func(i, j int) bool {
		if cs[i].Score == cs[j].Score {
			return cs[i].Name < cs[j].Name
		}
		return cs[i].Score > cs[j].Score
	})
	return cs
}

func color(code, text string) string {
	return "\033[" + code + "m" + text + "\033[0m"
}

func candidateDisplay(c Candidate) (name, path string) {
	path = color("2", c.Path)
	if c.Kind == "session" {
		return color("1;36", c.Name), path
	}
	return color("1;33", c.Name), path
}

func printCandidates() error {
	for _, c := range candidates() {
		name, path := candidateDisplay(c)
		fmt.Printf("%s\t%s\t%s\t%s\n", c.Kind, c.Value, name, path)
	}
	return nil
}

func autojumpScore(path string) float64 {
	h, _ := os.UserHomeDir()
	db := os.Getenv("AUTOJUMP_DATA_DIR")
	if db == "" {
		db = filepath.Join(h, ".local/share/autojump")
	}
	f, err := os.Open(filepath.Join(db, "autojump.txt"))
	if err != nil {
		return 0
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	for s.Scan() {
		parts := strings.SplitN(s.Text(), "\t", 2)
		if len(parts) == 2 && parts[1] == path {
			var score float64
			fmt.Sscanf(parts[0], "%f", &score)
			return score
		}
	}
	return 0
}

func recordVisit(path string) {
	if st, err := os.Stat(path); err != nil || !st.IsDir() {
		return
	}
	_ = exec.Command("autojump", "--add", path).Run()
}

func launcher(clientArg string) error {
	client, err := clientName(clientArg)
	if err != nil {
		return err
	}
	var input strings.Builder
	for _, c := range candidates() {
		name, path := candidateDisplay(c)
		fmt.Fprintf(&input, "%s\t%s\t%s\t%s\n", c.Kind, c.Value, name, path)
	}
	cmd := exec.Command("fzf", "--height=100%", "--layout=default", "--border=none", "--ansi", "--tiebreak=index", "--nth=1,2", "--with-nth=3,4", "--delimiter=\t", "--prompt=PROJECT> ", "--header=Search sessions and paths.")
	cmd.Env = append(os.Environ(), "FZF_DEFAULT_OPTS=")
	cmd.Stdin = strings.NewReader(input.String())
	out, err := cmd.Output()
	if err != nil {
		return nil
	}
	parts := strings.Split(strings.TrimSpace(string(out)), "\t")
	if len(parts) < 2 {
		return nil
	}
	if parts[0] == "session" {
		recordVisit(sessionRoot(parts[1]))
		return switchTo(parts[1], client)
	}
	recordVisit(parts[1])
	session, err := ensureProjectSession(parts[1])
	if err != nil {
		return err
	}
	return switchTo(session, client)
}

func launcherPopup(clientArg string) error {
	_, _, _, _, owner, err := popupContext(clientArg)
	if err != nil {
		return err
	}
	detachPopups(owner, "")
	cmd := "TMUX_PROJECT_CLIENT=" + shellQuote(owner) + " tmux_project launcher || true"
	_, err = tmux("display-popup", "-t", owner, "-E", "-w", "66%", "-h", "33%", cmd)
	return err
}

func switchProject(direction, clientArg string) error {
	if direction != "next" && direction != "prev" {
		usage()
	}
	client, err := clientName(clientArg)
	if err != nil {
		return err
	}
	current, err := currentSession(client)
	if err != nil {
		return err
	}
	cur := sessionByName(current)
	targetClient := client
	if cur.PopupOwner != "" {
		targetClient = cur.PopupOwner
	}
	project := rootForSession(current)
	roots := rootSessions()
	if len(roots) == 0 {
		return nil
	}
	idx := -1
	for i, s := range roots {
		if s.Name == project {
			idx = i
			break
		}
	}
	target := roots[0].Name
	if idx >= 0 {
		if direction == "next" {
			idx = (idx + 1) % len(roots)
		} else {
			idx = (idx + len(roots) - 1) % len(roots)
		}
		target = roots[idx].Name
	}
	if err := switchTo(target, targetClient); err != nil {
		return err
	}
	if targetClient != client {
		_, _ = tmux("detach-client", "-t", client)
	}
	return nil
}

func openGlobalPopup(group, clientArg string) error {
	return openGlobalCommandPopup(group, clientArg, "", false, false)
}

func openGlobalCommandPopup(group, clientArg, command string, force, newWindow bool) error {
	client, current, rootSession, rootPath, owner, err := popupContext(clientArg)
	if err != nil {
		return err
	}
	session := group
	if current == session && !force && !newWindow {
		_, _ = tmux("detach-client", "-t", client)
		return nil
	}
	existed := tmuxOk("has-session", "-t", "="+session)
	if !existed {
		if err := createSession(session, rootPath, command, false); err != nil {
			return err
		}
	}
	markPopupSession(session, roleGlobalTool, group, "", rootPath, owner, rootSession)
	if command != "" && (force || existed && current == session) {
		runInSession(session, command)
	}
	if newWindow {
		_, _ = tmux("new-window", "-t", "="+session+":", "-c", rootPath)
	}
	recordLastPopup(rootSession, roleGlobalTool, group)
	return showPopup(owner, session, rootPath)
}

func openSatellitePopup(group, clientArg string) error {
	return openSatelliteCommandPopup(group, clientArg, "", "", false, false)
}

func openSatelliteCommandPopup(group, clientArg, command, splitRight string, force, keep bool) error {
	client, current, rootSession, rootPath, owner, err := popupContext(clientArg)
	if err != nil {
		return err
	}
	session := group + "-" + sanitize(rootSession)
	if current == session && !force {
		_, _ = tmux("detach-client", "-t", client)
		return nil
	}
	existed := tmuxOk("has-session", "-t", "="+session)
	if !existed {
		if splitRight != "" {
			if err := createSplitSession(session, rootPath, splitRight); err != nil {
				return err
			}
		} else if err := createSession(session, rootPath, command, keep); err != nil {
			return err
		}
	}
	markPopupSession(session, roleSatellite, group, rootSession, rootPath, owner, rootSession)
	if command != "" && (force || existed) {
		runInSession(session, command)
	}
	recordLastPopup(rootSession, roleSatellite, group)
	return showPopup(owner, session, rootPath)
}

func markPopupSession(session, role, group, parent, rootPath, owner, popupRoot string) {
	setSessionOption(session, "@project_role", role)
	setSessionOption(session, "@project_group", group)
	setSessionOption(session, "@project_parent", parent)
	setSessionOption(session, "@project_root", rootPath)
	setSessionOption(session, "@project_popup_owner", owner)
	setSessionOption(session, "@project_popup_root", popupRoot)
}

func createSession(session, rootPath, command string, keep bool) error {
	args := []string{"new-session", "-d", "-s", session, "-c", rootPath}
	if command != "" {
		if keep {
			command += "; exec $SHELL"
		}
		args = append(args, command)
	}
	_, err := tmux(args...)
	return err
}

func createSplitSession(session, rootPath, splitRight string) error {
	left, err := tmux("new-session", "-d", "-P", "-F", "#{pane_id}", "-s", session, "-c", rootPath)
	if err != nil {
		return err
	}
	_, err = tmux("split-window", "-h", "-t", left, "-c", rootPath, splitRight)
	if err == nil {
		_, _ = tmux("select-pane", "-t", left)
	}
	return err
}

func runInSession(session, command string) {
	pane, err := tmux("list-panes", "-t", "="+session+":", "-F", "#{pane_id}")
	if err != nil || pane == "" {
		return
	}
	pane = strings.SplitN(pane, "\n", 2)[0]
	_, _ = tmux("send-keys", "-t", pane, "C-c")
	_, _ = tmux("send-keys", "-t", pane, command, "Enter")
}

func recordLastPopup(rootSession, kind, group string) {
	setSessionOption(rootSession, "@project_last_popup_kind", kind)
	setSessionOption(rootSession, "@project_last_popup_group", group)
}

func toggleLastPopup(clientArg string) error {
	client, err := clientName(clientArg)
	if err != nil {
		return err
	}
	current, err := currentSession(client)
	if err != nil {
		return err
	}
	cur := sessionByName(current)
	if cur.Role == roleGlobalTool || cur.Role == roleSatellite || cur.PopupOwner != "" {
		_, _ = tmux("detach-client", "-t", client)
		return nil
	}

	rootSession := rootForSession(current)
	kind := sessionOption(rootSession, "@project_last_popup_kind")
	group := sessionOption(rootSession, "@project_last_popup_group")
	if group == "" {
		kind = roleGlobalTool
		group = "scratch"
	}
	if kind == roleSatellite {
		if group == "rebuild" {
			return openSatelliteCommandPopup("rebuild", client, "", "", false, false)
		}
		return openSatellitePopup(group, client)
	}
	switch group {
	case "LLM":
		return openGlobalCommandPopup("LLM", client, "LLM", false, false)
	case "obsidian":
		return openGlobalCommandPopup("obsidian", client, "mkdir -p ~/documents/vault/main && cd ~/documents/vault/main && nvim -O ~/documents/vault/main/triage.md", false, false)
	default:
		return openGlobalPopup(group, client)
	}
}

func popupContext(clientArg string) (client, current, rootSession, rootPath, owner string, err error) {
	client, err = clientName(clientArg)
	if err != nil {
		return
	}
	current, err = currentSession(client)
	if err != nil {
		return
	}
	cur := sessionByName(current)
	rootSession = rootForSession(current)
	rootPath = sessionRoot(rootSession)
	owner = client
	if cur.PopupOwner != "" {
		owner = cur.PopupOwner
	}
	return
}

func showPopup(owner, session, rootPath string) error {
	detachPopups(owner, session)
	cmd := "tmux new-session -A -s " + shellQuote(session) + " -c " + shellQuote(rootPath)
	_, err := tmux("display-popup", "-t", owner, "-E", "-w", "95%", "-h", "95%", cmd)
	return err
}

func detachPopups(owner, keep string) {
	clients, err := tmux("list-clients", "-F", "#{client_name}\t#{session_name}")
	if err != nil {
		return
	}
	s := bufio.NewScanner(strings.NewReader(clients))
	for s.Scan() {
		parts := strings.Split(s.Text(), "\t")
		if len(parts) < 2 {
			continue
		}
		if parts[1] == keep {
			continue
		}
		sess := sessionByName(parts[1])
		if sess.PopupOwner == owner {
			_, _ = tmux("detach-client", "-t", parts[0])
		}
	}
}

func noteRootFocus(client, session string) error {
	if session == "" {
		var err error
		session, err = currentSession(client)
		if err != nil {
			return err
		}
	}
	if !tmuxOk("has-session", "-t", "="+session) {
		return nil
	}
	s := sessionByName(session)
	switch s.Role {
	case roleRoot:
		if s.Root == "" {
			markRoot(session, sessionRoot(session))
		}
		updateRootMRU(session)
	case "":
		markRoot(session, sessionRoot(session))
		updateRootMRU(session)
	}
	return nil
}

func rootMRU() []string {
	value := globalOption("@project_root_mru")
	if value == "" {
		return nil
	}
	parts := strings.Split(value, "\t")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		if part != "" {
			out = append(out, part)
		}
	}
	return out
}

func setRootMRU(items []string) {
	setGlobalOption("@project_root_mru", strings.Join(items, "\t"))
}

func updateRootMRU(session string) {
	items := []string{session}
	for _, item := range rootMRU() {
		if item != session && tmuxOk("has-session", "-t", "="+item) && isRoot(sessionByName(item)) {
			items = append(items, item)
		}
	}
	setRootMRU(items)
}

func removeRootMRU(session string) {
	items := make([]string, 0)
	for _, item := range rootMRU() {
		if item != session && tmuxOk("has-session", "-t", "="+item) && isRoot(sessionByName(item)) {
			items = append(items, item)
		}
	}
	setRootMRU(items)
}

func fallbackRoot(exclude string) string {
	for _, item := range rootMRU() {
		if item != exclude && tmuxOk("has-session", "-t", "="+item) && isRoot(sessionByName(item)) {
			return item
		}
	}
	for _, s := range rootSessions() {
		if s.Name != exclude {
			return s.Name
		}
	}
	return ""
}

func sessionClosed(closed string) error {
	removeRootMRU(closed)
	cleanupSatellites(closed)
	fallback := fallbackRoot(closed)
	if fallback == "" {
		return nil
	}
	clients, err := tmux("list-clients", "-F", "#{client_name}\t#{session_name}")
	if err != nil {
		return nil
	}
	s := bufio.NewScanner(strings.NewReader(clients))
	for s.Scan() {
		parts := strings.Split(s.Text(), "\t")
		if len(parts) < 2 {
			continue
		}
		client, session := parts[0], parts[1]
		if session == fallback {
			continue
		}
		if !isRoot(sessionByName(session)) {
			_ = switchTo(fallback, client)
		}
	}
	return nil
}

func cleanupSatellites(closed string) {
	sessions, _ := allSessions()
	for _, s := range sessions {
		if s.Role == roleSatellite && s.Parent == closed {
			_, _ = tmux("kill-session", "-t", "="+s.Name)
		}
	}
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'" }
