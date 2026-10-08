package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"time"
)

const pickerPathLimit = 4096

func pickerRoots() []string {
	h, _ := os.UserHomeDir()
	return []string{filepath.Join(h, "documents"), filepath.Join(h, "monash")}
}
func scanPickerPaths(ctx context.Context, roots []string) ([]string, error) {
	type scanResult struct {
		Paths []string
		Err   error
	}
	paths := make(chan scanResult, len(roots))
	var wg sync.WaitGroup
	for _, root := range roots {
		wg.Add(1)
		go func(root string) {
			defer wg.Done()
			if st, err := os.Stat(root); os.IsNotExist(err) {
				paths <- scanResult{}
				return
			} else if err != nil || !st.IsDir() {
				paths <- scanResult{Err: fmt.Errorf("discovery root unavailable")}
				return
			}
			cmd := exec.CommandContext(ctx, "fd", "-H", "-t", "d", "-t", "f", "^\\.git$", root, "--max-depth", "6", "--absolute-path", "--exclude", "node_modules", "--exclude", ".direnv", "--exclude", "result", "--exclude", ".venv", "--exclude", "venv")
			out := &pickerBoundedOutput{limit: 1024 * 1024}
			cmd.Stdout = out
			cmd.WaitDelay = 100 * time.Millisecond
			if err := cmd.Run(); err != nil {
				paths <- scanResult{Err: err}
				return
			}
			var found []string
			for _, line := range strings.Split(out.String(), "\n") {
				if line == "" {
					continue
				}
				path := filepath.Dir(strings.TrimRight(line, string(os.PathSeparator)))
				if pickerText(path, 4096) && filepath.IsAbs(path) {
					found = append(found, path)
				}
				if len(found) > pickerPathLimit {
					paths <- scanResult{Err: fmt.Errorf("discovery exceeds bound")}
					return
				}
			}
			paths <- scanResult{Paths: found}
		}(root)
	}
	wg.Wait()
	close(paths)
	seen := map[string]bool{}
	var result []string
	for found := range paths {
		if found.Err != nil {
			return nil, found.Err
		}
		for _, path := range found.Paths {
			if !seen[path] {
				seen[path] = true
				result = append(result, path)
			}
		}
	}
	if len(result) > pickerPathLimit {
		return nil, fmt.Errorf("discovery exceeds bound")
	}
	return result, ctx.Err()
}

type pickerPathCache struct {
	Version int      `json:"version"`
	Roots   []string `json:"roots"`
	Paths   []string `json:"paths"`
}

func pickerCacheFile() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if !filepath.IsAbs(base) {
		h, _ := os.UserHomeDir()
		base = filepath.Join(h, ".cache")
	}
	return filepath.Join(base, "tmux-project", "paths.json")
}
func loadPickerCache(path string, roots []string) []string {
	st, err := os.Lstat(path)
	if err != nil || !st.Mode().IsRegular() || st.Size() > 1024*1024 {
		return nil
	}
	file, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, 1024*1024+1))
	if err != nil || len(data) > 1024*1024 {
		return nil
	}
	var cache pickerPathCache
	if json.Unmarshal(data, &cache) != nil || cache.Version != 1 || !reflect.DeepEqual(cache.Roots, roots) || len(cache.Paths) > pickerPathLimit {
		return nil
	}
	var result []string
	seen := map[string]bool{}
	for _, path := range cache.Paths {
		if !pickerText(path, 4096) || !filepath.IsAbs(path) {
			return nil
		}
		if !seen[path] {
			if st, err := os.Stat(path); err == nil && st.IsDir() {
				result = append(result, path)
				seen[path] = true
			}
		}
	}
	return result
}
func publishPickerCache(ctx context.Context, path string, roots, paths []string) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if len(paths) > pickerPathLimit {
		return fmt.Errorf("path cache exceeds bound")
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	st, err := os.Lstat(dir)
	if err != nil || !st.IsDir() || st.Mode().Perm()&0077 != 0 {
		return fmt.Errorf("cache directory is not private")
	}
	data, err := json.Marshal(pickerPathCache{1, roots, paths})
	if err != nil {
		return err
	}
	if len(data) > 1024*1024 {
		return fmt.Errorf("path cache exceeds bound")
	}
	file, err := os.CreateTemp(dir, ".paths-")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err = file.Write(data); err != nil {
		file.Close()
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	// Disposable cache, not durable authority. Readers see one complete scan;
	// concurrent writers use distinct temporaries and may publish in either order.
	return os.Rename(file.Name(), path)
}

type pickerLocalSnapshot struct {
	Sessions  []Session
	Windows   []pickerWindow
	ClientPID string
}

func pickerSnapshot(ctx context.Context, client string) (pickerLocalSnapshot, error) {
	var result pickerLocalSnapshot
	cmd := exec.CommandContext(ctx, "tmux", "list-sessions", "-F", "S\t#{session_name}\t#{@project_root}\t#{@project_parent}\t#{@project_role}\t#{@project_group}\t#{@project_popup_owner}\t#{@project_popup_root}", ";", "list-windows", "-a", "-F", "W\t#{session_name}\t#{window_id}\t#{pane_id}\t#{@managed_pi_conversation_id}", ";", "list-clients", "-F", "C\t#{client_name}\t#{client_pid}")
	out := &pickerBoundedOutput{limit: 1024 * 1024}
	cmd.Stdout = out
	cmd.WaitDelay = 100 * time.Millisecond
	if err := cmd.Run(); err != nil {
		return result, err
	}
	for _, line := range strings.Split(strings.TrimSuffix(out.String(), "\n"), "\n") {
		p := strings.Split(line, "\t")
		switch p[0] {
		case "S":
			if len(p) == 8 {
				result.Sessions = append(result.Sessions, Session{p[1], p[2], p[3], p[4], p[5], p[6], p[7]})
			}
		case "W":
			if len(p) == 5 && pickerText(p[1], 128) && exactWindowPattern.MatchString(p[2]) && exactPanePattern.MatchString(p[3]) {
				result.Windows = append(result.Windows, pickerWindow{p[1], p[2], p[3], p[4]})
			}
		case "C":
			if len(p) == 3 && p[1] == client {
				if result.ClientPID != "" || !exactPID(p[2]) {
					return pickerLocalSnapshot{}, fmt.Errorf("ambiguous requesting client")
				}
				result.ClientPID = p[2]
			}
		}
	}
	if !validManagedClientName(client) || result.ClientPID == "" {
		return pickerLocalSnapshot{}, fmt.Errorf("requesting client unavailable")
	}
	return result, nil
}
