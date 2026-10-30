package main

import (
	"bufio"
	"context"
	"crypto/sha256"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

type pickerWindow struct{ Session, Window, Pane, Marker string }
type pickerRow struct {
	Key          string
	Candidate    Candidate
	Conversation *pickerConversation
	Ordinary     *pickerWindow
}

func pickerWindows(run exactTmux) []pickerWindow {
	out, err := run("list-windows", "-a", "-F", "#{session_name}\t#{window_id}\t#{pane_id}\t#{@managed_pi_conversation_id}")
	if err != nil || len(out) > 1024*1024 {
		return nil
	}
	var rows []pickerWindow
	for _, line := range strings.Split(out, "\n") {
		p := strings.Split(line, "\t")
		if len(p) != 4 || !pickerText(p[0], 128) || !exactWindowPattern.MatchString(p[1]) || !exactPanePattern.MatchString(p[2]) {
			continue
		}
		rows = append(rows, pickerWindow{p[0], p[1], p[2], p[3]})
	}
	return rows
}
func pickerScores() map[string]float64 {
	h, _ := os.UserHomeDir()
	dir := os.Getenv("AUTOJUMP_DATA_DIR")
	if dir == "" {
		dir = filepath.Join(h, ".local/share/autojump")
	}
	scores := map[string]float64{}
	f, err := os.Open(filepath.Join(dir, "autojump.txt"))
	if err != nil {
		return scores
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	for n := 0; s.Scan() && n < 65536; n++ {
		p := strings.SplitN(s.Text(), "\t", 2)
		if len(p) == 2 {
			if score, err := strconv.ParseFloat(p[0], 64); err == nil && score >= 0 && score < 1e15 {
				scores[p[1]] = score
			}
		}
	}
	return scores
}
func pickerCheckout(host, project, path string) string {
	h := sha256.New()
	fmt.Fprint(h, "pi-managed-sessions:checkout:live-v1\x00")
	for _, part := range []string{host, project, path} {
		fmt.Fprintf(h, "%d:%s", len(part), part)
	}
	return fmt.Sprintf("checkout_%x", h.Sum(nil)[:16])
}
func pickerCanonical(path string) string {
	if !filepath.IsAbs(path) || !pickerText(path, 4096) {
		return ""
	}
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return ""
	}
	st, err := os.Stat(resolved)
	if err != nil || !st.IsDir() {
		return ""
	}
	return filepath.Clean(resolved)
}
func buildPickerRows(ctx context.Context, sessions []Session, windows []pickerWindow, paths []string, inventory pickerInventory, scores map[string]float64) []pickerRow {
	// Match checkout digests against locally discovered canonical paths. Relative
	// cwd and display names never identify a checkout; no Git subprocess is needed.
	if ctx.Err() != nil {
		return nil
	}
	roots := map[string]bool{}
	rawRoots := map[string]bool{}
	ordinaryRoots := map[string]bool{}
	managedRoots := map[string]bool{}
	for _, path := range paths {
		if ctx.Err() != nil {
			return nil
		}
		if root := pickerCanonical(path); root != "" {
			roots[root] = true
			rawRoots[root] = true
		}
	}
	for _, s := range sessions {
		if ctx.Err() != nil {
			return nil
		}
		if root := pickerCanonical(s.Root); root != "" {
			roots[root] = true
		}
	}
	var rows []pickerRow
	for _, s := range sessions {
		if ctx.Err() != nil {
			return nil
		}
		if !isRoot(s) || !pickerText(s.Name, 128) {
			continue
		}
		for _, w := range windows {
			if w.Session != s.Name || w.Marker != "" {
				continue
			}
			root := pickerCanonical(s.Root)
			ordinaryRoots[root] = true
			window := w
			rows = append(rows, pickerRow{Key: "session:" + s.Name, Candidate: Candidate{Kind: "session", Value: s.Name, Name: s.Name, Path: homeRelative(root), Session: s.Name, Score: scores[root]}, Ordinary: &window})
			break
		}
	}
	projects, checkouts := map[string]bool{}, map[string]bool{}
	for _, item := range inventory.Rows {
		if item.CheckoutID != "" {
			projects[item.ProjectKey] = true
			checkouts[item.CheckoutID] = true
		}
	}
	matched := map[string]string{}
	for candidate := range roots {
		for project := range projects {
			if ctx.Err() != nil {
				return nil
			}
			id := pickerCheckout(inventory.HostID, project, candidate)
			if checkouts[id] {
				matched[id] = candidate
				managedRoots[candidate] = true
			}
		}
	}
	for _, item := range inventory.Rows {
		row := item
		root := matched[item.CheckoutID]
		state := "ownership unknown"
		switch {
		case item.LaunchState == "failed" && item.RuntimeState == "unknown":
			state = "launch failed; ownership unknown"
		case item.LaunchState == "failed":
			state = "launch failed; Enter retries"
		case item.LaunchState == "prepared" || item.LaunchState == "window_created":
			state = "starting"
		case item.RuntimeState == "running":
			state = "running"
		case item.RuntimeState == "stopped":
			state = "dormant"
		}
		path := item.Kind
		if pickerText(item.CheckoutDisplayName, 512) {
			path = item.CheckoutDisplayName
		}
		if root != "" {
			path = homeRelative(root)
		}
		rows = append(rows, pickerRow{Key: "conversation:" + item.ConversationID, Candidate: Candidate{Kind: "conversation", Value: item.ConversationID, Name: item.Title + " [" + item.ConversationID + "; " + state + "]", Path: path, Score: scores[root]}, Conversation: &row})
	}
	for path := range rawRoots {
		if ordinaryRoots[path] || managedRoots[path] {
			continue
		}
		rows = append(rows, pickerRow{Key: "path:" + path, Candidate: Candidate{Kind: "path", Value: path, Name: filepath.Base(path), Path: homeRelative(path), Score: scores[path]}})
	}
	sort.Slice(rows, func(i, j int) bool {
		a, b := rows[i], rows[j]
		if a.Candidate.Score != b.Candidate.Score {
			return a.Candidate.Score > b.Candidate.Score
		}
		if a.Candidate.Name != b.Candidate.Name {
			return a.Candidate.Name < b.Candidate.Name
		}
		return a.Key < b.Key
	})
	return rows
}
func capturePickerClient(client string, run exactTmux) (string, error) {
	if !validManagedClientName(client) {
		return "", fmt.Errorf("invalid requesting client")
	}
	out, err := run("list-clients", "-F", "#{client_name}\t#{client_pid}")
	if err != nil {
		return "", err
	}
	if len(out) > 65536 {
		return "", fmt.Errorf("client inventory exceeds bound")
	}
	pid := ""
	for _, line := range strings.Split(out, "\n") {
		p := strings.Split(line, "\t")
		if len(p) == 2 && p[0] == client {
			if pid != "" || !exactPID(p[1]) {
				return "", fmt.Errorf("ambiguous requesting client")
			}
			pid = p[1]
		}
	}
	if pid == "" {
		return "", fmt.Errorf("requesting client detached")
	}
	return pid, nil
}
func focusPickerOrdinary(w pickerWindow, client, pid string, run exactTmux) error {
	if w.Marker != "" || !pickerText(w.Session, 128) || strings.ContainsAny(w.Session, "#{},") || !exactWindowPattern.MatchString(w.Window) || !exactPanePattern.MatchString(w.Pane) || !validManagedClientName(client) || !exactPID(pid) {
		return fmt.Errorf("invalid ordinary target")
	}
	condition := formatAnd(formatEqual("session_name", w.Session), formatEqual("window_id", w.Window), formatEqual("pane_id", w.Pane), formatEqual(managedWindowOption, ""),
		"#{m:*1*,#{L:"+formatAnd(formatEqual("client_name", client), formatEqual("client_pid", pid), "#{!=:#{client_session},}")+"}}")
	out, err := run("if-shell", "-F", "-t", w.Pane, condition, "switch-client -c "+shellQuote(client)+" -t "+shellQuote("="+w.Session+":"+w.Window+"."+w.Pane), "display-message -p picker-target-stale")
	if err != nil {
		return err
	}
	if strings.TrimSpace(out) != "" {
		return fmt.Errorf("ordinary target or requester changed")
	}
	return nil
}
func selectPickerPath(path, client, pid string) error {
	root := pickerCanonical(path)
	if root == "" || root != path {
		return fmt.Errorf("selected path changed")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", root, "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil || pickerCanonical(strings.TrimSpace(string(out))) != root {
		return fmt.Errorf("selected path is no longer a Git checkout")
	}
	// Verify caller before any ordinary shell creation, then queue-guard focus too.
	current, err := capturePickerClient(client, tmux)
	if err != nil || current != pid {
		return fmt.Errorf("requester changed")
	}
	session, err := ensureProjectSession(root)
	if err != nil {
		return err
	}
	windows := pickerWindows(tmux)
	for _, w := range windows {
		if w.Session == session && w.Marker == "" {
			recordVisit(root)
			return focusPickerOrdinary(w, client, pid, tmux)
		}
	}
	// A raw path may coincide with a managed-only project session during outage.
	// Enter creates an ordinary shell, never focuses its managed last window.
	outString, err := tmux("new-window", "-d", "-P", "-F", "#{window_id}\t#{pane_id}", "-t", "="+session, "-c", root)
	if err != nil {
		return err
	}
	parts := strings.Split(outString, "\t")
	if len(parts) != 2 {
		return fmt.Errorf("ordinary window result invalid")
	}
	recordVisit(root)
	return focusPickerOrdinary(pickerWindow{Session: session, Window: parts[0], Pane: parts[1]}, client, pid, tmux)
}
func discoverPickerRows() []pickerRow {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	inventory, _ := loadPickerInventory(ctx, callPickerHost)
	sessions, _ := allSessions()
	return buildPickerRows(context.Background(), sessions, pickerWindows(tmux), projectPaths(), inventory, pickerScores())
}
func runPicker(clientArg string) error { return runProgressivePicker(clientArg) }
