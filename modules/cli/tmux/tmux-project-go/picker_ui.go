package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Short-lived, private UI snapshots are not a registry or a launch journal.
// fzf's --track tracks source indices across reloads, not our immutable IDs.
// Capture the key inside fzf's event queue, then restore it after full reload.
type pickerUIRow struct{ Key, Line string }
type pickerUIData struct {
	Revision int
	Rows     []pickerUIRow
}
type pickerUISelection struct {
	Revision int
	Key      string
}
type pickerUIState struct {
	Reading    bool   `json:"reading"`
	TotalCount int    `json:"totalCount"`
	Query      string `json:"query"`
	Current    *struct {
		Text string `json:"text"`
	} `json:"current"`
	Matches []struct {
		Text string `json:"text"`
	} `json:"matches"`
}

func pickerPrivateDir(dir string) error {
	st, err := os.Lstat(dir)
	if err != nil || !st.IsDir() || st.Mode().Perm()&0077 != 0 || !strings.HasPrefix(filepath.Base(dir), "tmux-picker-") {
		return fmt.Errorf("invalid private picker directory")
	}
	return nil
}
func pickerReadJSON(path string, target any) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, 8*1024*1024+1))
	if err != nil {
		return err
	}
	if len(data) > 8*1024*1024 {
		return fmt.Errorf("picker data exceeds bound")
	}
	return json.Unmarshal(data, target)
}
func pickerWriteJSON(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	if len(data) > 8*1024*1024 {
		return fmt.Errorf("picker data exceeds bound")
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".ui-")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}
func pickerUIRequest(ctx context.Context, socket, body string, target any) error {
	transport := &http.Transport{DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "unix", socket)
	}}
	defer transport.CloseIdleConnections()
	method := http.MethodGet
	var reader io.Reader
	if body != "" {
		method = http.MethodPost
		reader = strings.NewReader(body)
	}
	url := "http://picker/?limit=8192"
	if method == http.MethodPost {
		url = "http://picker/"
	}
	req, err := http.NewRequestWithContext(ctx, method, url, reader)
	if err != nil {
		return err
	}
	response, err := (&http.Client{Transport: transport, Timeout: 500 * time.Millisecond}).Do(req)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		return fmt.Errorf("picker UI refused update (HTTP %d)", response.StatusCode)
	}
	if target == nil {
		return nil
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, 8*1024*1024+1))
	if err != nil {
		return err
	}
	if len(data) > 8*1024*1024 {
		return fmt.Errorf("picker state exceeds bound")
	}
	return json.Unmarshal(data, target)
}
func pickerUIHelper(operation, dir, key string) error {
	if err := pickerPrivateDir(dir); err != nil {
		return err
	}
	var data pickerUIData
	if err := pickerReadJSON(filepath.Join(dir, "rows.json"), &data); err != nil {
		return err
	}
	switch operation {
	case "picker-lines":
		for _, row := range data.Rows {
			fmt.Println(row.Line)
		}
		return nil
	case "picker-refresh":
		if err := pickerWriteJSON(filepath.Join(dir, "selection.json"), pickerUISelection{data.Revision, key}); err != nil {
			return err
		}
		exe, err := os.Executable()
		if err != nil {
			return err
		}
		fmt.Printf("unbind(enter)+reload-sync(%s picker-lines %s)\n", shellQuote(exe), shellQuote(dir))
		return nil
	case "picker-restore":
		var applied int
		if pickerReadJSON(filepath.Join(dir, "applied.json"), &applied) == nil && applied == data.Revision {
			return nil
		}
		var selection pickerUISelection
		if err := pickerReadJSON(filepath.Join(dir, "selection.json"), &selection); os.IsNotExist(err) {
			return nil
		} else if err != nil {
			return err
		}
		var state pickerUIState
		if err := pickerUIRequest(context.Background(), filepath.Join(dir, "ui.sock"), "", &state); err != nil {
			return err
		}
		if selection.Revision != data.Revision || state.Reading || state.TotalCount != len(data.Rows) {
			return nil
		}
		action := "rebind(enter)"
		if selection.Key != "" {
			action = "unbind(enter)+change-header(Selection changed; move or edit query before Enter.)"
			for index, item := range state.Matches {
				if strings.SplitN(item.Text, "\t", 2)[0] == selection.Key {
					action = "pos(" + strconv.Itoa(index+1) + ")+rebind(enter)"
					break
				}
			}
		}
		fmt.Println(action)
		return pickerWriteJSON(filepath.Join(dir, "applied.json"), data.Revision)
	}
	return fmt.Errorf("unknown picker UI helper")
}
func publishPickerUI(ctx context.Context, dir, exe string, revision int, rows []pickerRow) error {
	data := pickerUIData{Revision: revision}
	for _, row := range rows {
		name, path := candidateDisplay(row.Candidate)
		data.Rows = append(data.Rows, pickerUIRow{row.Key, row.Key + "\t" + name + "\t" + path})
	}
	if len(data.Rows) > 8192 {
		return fmt.Errorf("picker row bound exceeded")
	}
	if err := pickerWriteJSON(filepath.Join(dir, "rows.json"), data); err != nil {
		return err
	}
	action := "transform(" + shellQuote(exe) + " picker-refresh " + shellQuote(dir) + " {1})"
	if err := pickerUIRequest(ctx, filepath.Join(dir, "ui.sock"), action, nil); err != nil {
		return err
	}
	timer := time.NewTimer(2 * time.Second)
	defer timer.Stop()
	ticker := time.NewTicker(5 * time.Millisecond)
	defer ticker.Stop()
	for {
		var applied int
		if pickerReadJSON(filepath.Join(dir, "applied.json"), &applied) == nil && applied == revision {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-timer.C:
			return fmt.Errorf("picker reload did not acknowledge its identity fence")
		case <-ticker.C:
		}
	}
}
func pickerUIArgs(dir, exe string) []string {
	return []string{"--height=100%", "--layout=default", "--border=none", "--ansi", "--tiebreak=index", "--with-nth=2,3", "--delimiter=\t", "--prompt=PROJECT> ", "--header=Enter opens. Managed selection requires the relay.", "--listen=" + filepath.Join(dir, "ui.sock"), "--bind=result:transform:" + shellQuote(exe) + " picker-restore " + shellQuote(dir), "--bind=up:up+rebind(enter),down:down+rebind(enter),ctrl-p:up+rebind(enter),ctrl-n:down+rebind(enter),change:rebind(enter)"}
}
