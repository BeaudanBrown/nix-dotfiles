package main

import (
	"strings"
	"testing"
)

func TestManagedClientCaptureRequiresOriginalServerAndUnambiguousPane(t *testing.T) {
	run := exactTestServer(t)
	exactTestWindow(t, run, "a")
	first, pid := focusTestClient(t, run, "exact")
	server, err := run("display-message", "-p", "#{pid}")
	if err != nil {
		t.Fatal(err)
	}
	pane, err := run("list-clients", "-F", "#{pane_id}")
	if err != nil {
		t.Fatal(err)
	}
	request := managedClientRequest{PaneID: pane, SourceServerPID: server}
	captured, err := captureManagedClient(run, request)
	if err != nil || captured.ClientName != first || captured.ClientPID != pid {
		t.Fatalf("capture = %+v, %v (request %+v)", captured, err, request)
	}
	focusTestClient(t, run, "exact")
	if _, err := captureManagedClient(run, request); err == nil {
		t.Fatal("shared pane guessed a client")
	}
	request.ClientName = first
	if got, err := captureManagedClient(run, request); err != nil || got != captured {
		t.Fatalf("explicit client = %+v, %v", got, err)
	}
	foreign := request
	foreign.SourceServerPID = "1"
	if _, err := captureManagedClient(run, foreign); err == nil {
		t.Fatal("foreign server reused a pane ID")
	}
	if _, err := run("detach-client", "-t", first); err != nil {
		t.Fatal(err)
	}
	if _, err := captureManagedClient(run, request); err == nil {
		t.Fatal("detached client fell back to another viewer")
	}
}

func TestManagedClientCaptureBoundsAndRefusals(t *testing.T) {
	valid := managedClientRequest{PaneID: "%1", SourceServerPID: "123"}
	for _, rows := range []string{"", "bad", "client\tbad\t%1\t123", "client\t42\t%1\t123\nclient\t42\t%1\t123", strings.Repeat("x", 65537)} {
		if _, err := captureManagedClient(func(...string) (string, error) { return rows, nil }, valid); err == nil {
			t.Fatal("invalid inventory accepted")
		}
	}
	for _, request := range []managedClientRequest{{}, {PaneID: "%1", SourceServerPID: "123", ClientName: "bad\nname"}, {PaneID: "%1", SourceServerPID: "0"}} {
		called := false
		if _, err := captureManagedClient(func(...string) (string, error) { called = true; return "", nil }, request); err == nil || called {
			t.Fatal("invalid request reached tmux")
		}
	}
}
