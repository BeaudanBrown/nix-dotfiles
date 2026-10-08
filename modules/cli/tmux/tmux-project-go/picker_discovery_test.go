package main

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"sync"
	"testing"
	"time"
)

func TestPickerCachePublicationCancellationAndMalformedMiss(t *testing.T) {
	base := t.TempDir()
	cache := filepath.Join(base, "cache", "paths.json")
	a, b := t.TempDir(), t.TempDir()
	roots := []string{base}
	if err := publishPickerCache(context.Background(), cache, roots, []string{a, b}); err != nil {
		t.Fatal(err)
	}
	if got := loadPickerCache(cache, roots); !reflect.DeepEqual(got, []string{a, b}) {
		t.Fatal(got)
	}
	if err := os.Remove(b); err != nil {
		t.Fatal(err)
	}
	if got := loadPickerCache(cache, roots); !reflect.DeepEqual(got, []string{a}) {
		t.Fatal("removed path retained", got)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := publishPickerCache(ctx, cache, roots, nil); err == nil {
		t.Fatal("cancelled writer published")
	}
	var wg sync.WaitGroup
	for n := 0; n < 16; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := publishPickerCache(context.Background(), cache, roots, []string{a}); err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	if got := loadPickerCache(cache, roots); !reflect.DeepEqual(got, []string{a}) {
		t.Fatal("concurrent cache incomplete", got)
	}
	files, _ := os.ReadDir(filepath.Dir(cache))
	if len(files) != 1 {
		t.Fatal("temporary files leaked")
	}
	for _, data := range []string{"{", `{"version":7,"roots":[],"paths":[]}`, `{"version":1,"roots":[],"paths":["relative"]}`} {
		if err := os.WriteFile(cache, []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
		if got := loadPickerCache(cache, roots); got != nil {
			t.Fatal("malformed cache not missed")
		}
	}
}
func TestPickerScansRootsConcurrentlyWithoutGitAndCancels(t *testing.T) {
	bin := t.TempDir()
	first, second := t.TempDir(), t.TempDir()
	t.Setenv("PATH", bin+":"+os.Getenv("PATH"))
	t.Setenv("FIRST", first)
	t.Setenv("SECOND", second)
	fd := filepath.Join(bin, "fd")
	script := "#!/bin/sh\n: > \"$7/started\"\nwhile [ ! -f \"$FIRST/started\" ] || [ ! -f \"$SECOND/started\" ]; do sleep .01; done\nprintf '%s/repository/.git\\n' \"$7\"\n"
	if err := os.WriteFile(fd, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(bin, "git"), []byte("#!/bin/sh\nexit 99\n"), 0700); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	paths, err := scanPickerPaths(ctx, []string{first, second})
	if err != nil || len(paths) != 2 {
		t.Fatalf("concurrent scan: %v %v", paths, err)
	}
	if err := os.WriteFile(fd, []byte("#!/bin/sh\nexec sleep 30\n"), 0700); err != nil {
		t.Fatal(err)
	}
	ctx2, cancel2 := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer cancel2()
	started := time.Now()
	if _, err := scanPickerPaths(ctx2, []string{first, second}); err == nil {
		t.Fatal("cancelled scan succeeded")
	}
	if time.Since(started) > time.Second {
		t.Fatal("cancelled discovery did not drain")
	}
	if err := os.WriteFile(fd, []byte("#!/bin/sh\nexit 1\n"), 0700); err != nil {
		t.Fatal(err)
	}
	if _, err := scanPickerPaths(context.Background(), []string{first}); err == nil {
		t.Fatal("failed scan became complete cache")
	}
}
func TestPickerSnapshotUsesOneTmuxInventory(t *testing.T) {
	run := exactTestServer(t)
	client, pid := focusTestClient(t, run, "exact")
	socket, err := run("display-message", "-p", "#{socket_path}")
	if err != nil {
		t.Fatal(err)
	}
	server, err := run("display-message", "-p", "#{pid}")
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("TMUX", socket+","+server+",0")
	snapshot, err := pickerSnapshot(context.Background(), client)
	if err != nil || snapshot.ClientPID != pid || len(snapshot.Sessions) != 1 || len(snapshot.Windows) != 1 {
		t.Fatalf("snapshot: %+v %v", snapshot, err)
	}
}
