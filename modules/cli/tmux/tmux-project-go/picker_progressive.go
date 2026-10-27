package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"time"
)

type pickerUpdate struct {
	Kind      string
	Local     pickerLocalSnapshot
	Inventory pickerInventory
	Paths     []string
	Scores    map[string]float64
	Err       error
}
type pickerSelectionState struct {
	sync.Mutex
	Rows map[string]pickerRow
	PID  string
}

func discoverPickerProgressively(ctx context.Context, client string, emit func(pickerUpdate)) {
	var wg sync.WaitGroup
	start := func(fn func()) { wg.Add(1); go func() { defer wg.Done(); fn() }() }
	roots := pickerRoots()
	cache := pickerCacheFile()
	start(func() {
		limited, cancel := context.WithTimeout(ctx, 2*time.Second)
		defer cancel()
		local, err := pickerSnapshot(limited, client)
		emit(pickerUpdate{Kind: "local", Local: local, Scores: pickerScores(), Err: err})
	})
	start(func() {
		limited, cancel := context.WithTimeout(ctx, 2*time.Second)
		defer cancel()
		inventory, err := loadPickerInventory(limited, callPickerHost)
		emit(pickerUpdate{Kind: "managed", Inventory: inventory, Err: err})
	})
	start(func() { emit(pickerUpdate{Kind: "cache", Paths: loadPickerCache(cache, roots)}) })
	start(func() {
		limited, cancel := context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
		paths, err := scanPickerPaths(limited, roots)
		if err == nil {
			_ = publishPickerCache(limited, cache, roots, paths)
		}
		emit(pickerUpdate{Kind: "scan", Paths: paths, Err: err})
	})
	wg.Wait()
}
func drivePickerUI(ctx context.Context, client, dir, exe string, state *pickerSelectionState) error {
	ctx, cancelDiscovery := context.WithCancel(ctx)
	defer cancelDiscovery()
	// Start the terminal first. Even slow/missing relay and discovery cannot defer it.
	readyCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	for {
		var status pickerUIState
		if pickerUIRequest(readyCtx, filepath.Join(dir, "ui.sock"), "", &status) == nil {
			break
		}
		select {
		case <-readyCtx.Done():
			return readyCtx.Err()
		case <-time.After(5 * time.Millisecond):
		}
	}
	updates := make(chan pickerUpdate, 4)
	done := make(chan struct{})
	go func() {
		defer close(done)
		discoverPickerProgressively(ctx, client, func(update pickerUpdate) {
			select {
			case updates <- update:
			case <-ctx.Done():
			}
		})
		close(updates)
	}()
	defer func() { cancelDiscovery(); <-done }()
	// Leave headroom for the UI reload inside the <=100ms raw-path budget.
	hold := time.NewTimer(50 * time.Millisecond)
	defer hold.Stop()
	var local pickerLocalSnapshot
	var inventory pickerInventory
	var paths []string
	var scores map[string]float64
	localReady, rawReady, fresh := false, false, false
	revision := 0
	var previous []pickerRow
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-hold.C:
			rawReady = true
		case update, ok := <-updates:
			if !ok {
				// Private completion receipt for disposable UI/latency verification;
				// it carries no conversation state or mutation authority.
				return pickerWriteJSON(filepath.Join(dir, "discovery.json"), struct{ Complete bool }{true})
			}
			switch update.Kind {
			case "local":
				if update.Err != nil {
					return update.Err
				}
				local = update.Local
				scores = update.Scores
				localReady = true
			case "managed":
				inventory = update.Inventory
				rawReady = true
			case "cache":
				if !fresh {
					paths = update.Paths
				}
			case "scan":
				if update.Err == nil {
					paths = update.Paths
					fresh = true
				}
			}
		}
		if !localReady {
			continue
		}
		shown := paths
		if !rawReady {
			shown = nil
		}
		rows := buildPickerRows(ctx, local.Sessions, local.Windows, shown, inventory, scores)
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if reflect.DeepEqual(previous, rows) {
			continue
		}
		previous = rows
		revision++
		state.Lock()
		state.PID = local.ClientPID
		state.Rows = map[string]pickerRow{}
		for _, row := range rows {
			state.Rows[row.Key] = row
		}
		state.Unlock()
		if err := publishPickerUI(ctx, dir, exe, revision, rows); err != nil {
			return err
		}
	}
}
func runProgressivePicker(clientArg string) error {
	client, err := clientName(clientArg)
	if err != nil {
		return err
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	dir, err := os.MkdirTemp("", "tmux-picker-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)
	if err = pickerWriteJSON(filepath.Join(dir, "rows.json"), pickerUIData{}); err != nil {
		return err
	}
	cmd := exec.Command("fzf", pickerUIArgs(dir, exe)...)
	cmd.Env = append(os.Environ(), "FZF_DEFAULT_OPTS=", "FZF_DEFAULT_OPTS_FILE=", "FZF_API_KEY=")
	cmd.Stdin = strings.NewReader("")
	cmd.Stderr = os.Stderr
	out := &pickerBoundedOutput{limit: 65536}
	cmd.Stdout = out
	if err = cmd.Start(); err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	state := &pickerSelectionState{}
	driver := make(chan error, 1)
	go func() {
		err := drivePickerUI(ctx, client, dir, exe, state)
		driver <- err
		if err != nil && ctx.Err() == nil {
			_ = cmd.Process.Kill()
		}
	}()
	exit := cmd.Wait()
	cancel()
	discoveryErr := <-driver
	if exit != nil {
		if discoveryErr != nil && discoveryErr != context.Canceled {
			return discoveryErr
		}
		if aborted, ok := exit.(*exec.ExitError); ok && aborted.ExitCode() == 130 {
			return nil
		}
		return fmt.Errorf("picker UI failed: %w", exit)
	}
	if discoveryErr != nil && discoveryErr != context.Canceled {
		return discoveryErr
	}
	key := strings.SplitN(strings.TrimSuffix(out.String(), "\n"), "\t", 2)[0]
	state.Lock()
	row, ok := state.Rows[key]
	pid := state.PID
	state.Unlock()
	if !ok || pid == "" {
		return fmt.Errorf("selection changed; open picker again")
	}
	// Deliberately independent of the cancelled discovery context. Accepted host
	// work is never cancelled or replayed by UI/scanner lifetime.
	if row.Conversation != nil {
		openCtx, done := context.WithTimeout(context.Background(), 35*time.Second)
		defer done()
		return openPickerConversation(openCtx, callPickerHost, *row.Conversation, client, pid, tmux)
	}
	if row.Ordinary != nil {
		return focusPickerOrdinary(*row.Ordinary, client, pid, tmux)
	}
	return selectPickerPath(row.Candidate.Value, client, pid)
}
