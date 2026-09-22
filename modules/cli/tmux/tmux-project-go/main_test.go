package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"testing"
)

func TestProjectPathsIncludesMainCheckoutAndLinkedWorktree(t *testing.T) {
	home := t.TempDir()
	documents := filepath.Join(home, "documents")
	mainCheckout := filepath.Join(documents, "project")
	linkedWorktree := filepath.Join(documents, "project-feature")
	if err := os.MkdirAll(mainCheckout, 0o755); err != nil {
		t.Fatal(err)
	}
	runGit(t, mainCheckout, "init", "-b", "main")
	if err := os.WriteFile(filepath.Join(mainCheckout, "README.md"), []byte("test\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, mainCheckout, "add", "README.md")
	runGit(t, mainCheckout, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-m", "initial")
	runGit(t, mainCheckout, "worktree", "add", "-b", "feature", linkedWorktree)

	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	fakeFD := `#!/bin/sh
set -eu
finds_directory=false
finds_file=false
while [ "$#" -gt 0 ]; do
  if [ "$1" = -t ]; then
    shift
    case "$1" in
      d) finds_directory=true ;;
      f) finds_file=true ;;
    esac
  fi
  shift
done
[ "$finds_directory" = true ]
[ "$finds_file" = true ]
printf '%s\n%s\n' "$FD_MAIN_GIT" "$FD_WORKTREE_GIT"
`
	if err := os.WriteFile(filepath.Join(bin, "fd"), []byte(fakeFD), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("FD_MAIN_GIT", filepath.Join(mainCheckout, ".git"))
	t.Setenv("FD_WORKTREE_GIT", filepath.Join(linkedWorktree, ".git"))

	got := projectPaths()
	want := []string{mainCheckout, linkedWorktree}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("projectPaths() = %#v, want %#v", got, want)
	}
}

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, output)
	}
}
