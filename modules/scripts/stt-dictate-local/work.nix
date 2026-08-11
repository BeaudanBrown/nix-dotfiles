{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "stt-dictate-local";
      runtimeInputs = with pkgs; [
        coreutils
        libnotify
        pipewire
        procps
        socat
        util-linux
        wl-clipboard
        wtype
      ];
      text = ''
        set -euo pipefail

        cmd="''${1:-}"
        if [[ "$cmd" != "toggle" ]]; then
          echo "usage: stt-dictate-local toggle" >&2
          exit 2
        fi
        if [[ -z "''${XDG_RUNTIME_DIR:-}" ]]; then
          echo "XDG_RUNTIME_DIR is not set" >&2
          exit 1
        fi

        SOCKET="$XDG_RUNTIME_DIR/moonshine-stt/stt.sock"
        SESSION_PID_FILE="$XDG_RUNTIME_DIR/stt-dictate-local.pid"
        RECORDER_PID_FILE="$XDG_RUNTIME_DIR/stt-dictate-local-recorder.pid"
        FIFO="$XDG_RUNTIME_DIR/stt-dictate-local.pcm"
        RESPONSE="$XDG_RUNTIME_DIR/stt-dictate-local.response"
        RECORD_LOG="$XDG_RUNTIME_DIR/stt-dictate-local.pw-record.log"
        LOCKFILE="$XDG_RUNTIME_DIR/stt-dictate-local.lock"

        notify() {
          (notify-send "STT" "$1" >/dev/null 2>&1) || true
        }

        is_alive() {
          [[ "$1" =~ ^[0-9]+$ ]] && kill -0 "$1" 2>/dev/null
        }

        run_session() {
          local self recorder_pid status text
          self="$BASHPID"
          exec 9>&-

          # Invoked indirectly by the EXIT trap below.
          # shellcheck disable=SC2329
          cleanup() {
            if [[ "$(cat "$SESSION_PID_FILE" 2>/dev/null || true)" == "$self" ]]; then
              rm -f "$SESSION_PID_FILE" "$RECORDER_PID_FILE"
            fi
            rm -f "$FIFO"
          }
          trap cleanup EXIT

          rm -f "$FIFO" "$RESPONSE" "$RECORD_LOG"
          mkfifo -m 600 "$FIFO"

          pw-record \
            --raw \
            --rate 16000 \
            --channels 1 \
            --format s16 \
            "$FIFO" 2>"$RECORD_LOG" &
          recorder_pid=$!
          printf '%s\n' "$recorder_pid" >"$RECORDER_PID_FILE"

          set +e
          socat -t 30 - "UNIX-CONNECT:$SOCKET" <"$FIFO" >"$RESPONSE"
          status=$?
          wait "$recorder_pid" 2>/dev/null
          set -e

          if [[ "$status" -ne 0 ]]; then
            notify "Error: local transcription connection failed"
            exit 1
          fi
          if [[ ! -s "$RESPONSE" ]]; then
            notify "Error: local transcription returned no response"
            exit 1
          fi

          status="$(head -n 1 "$RESPONSE")"
          text="$(tail -n +2 "$RESPONSE")"
          if [[ "$status" != "OK" || -z "$text" ]]; then
            notify "Error: ''${text:-transcription failed}"
            exit 1
          fi

          printf %s "$text" | wl-copy
          printf %s "$text" | wl-copy --primary
          wtype -M ctrl -M shift -k v -m shift -m ctrl
          notify "Done"
        }

        exec 9>"$LOCKFILE"
        if ! flock -n 9; then
          notify "Busy"
          exit 0
        fi

        session_pid="$(cat "$SESSION_PID_FILE" 2>/dev/null || true)"
        if is_alive "$session_pid"; then
          recorder_pid="$(cat "$RECORDER_PID_FILE" 2>/dev/null || true)"
          if ! is_alive "$recorder_pid"; then
            notify "Error: recorder is not running"
            exit 1
          fi
          kill -INT "$recorder_pid"
          exit 0
        fi

        rm -f "$SESSION_PID_FILE" "$RECORDER_PID_FILE" "$FIFO" "$RESPONSE"
        if [[ ! -S "$SOCKET" ]]; then
          notify "Error: local STT daemon is unavailable"
          exit 1
        fi

        run_session &
        session_pid=$!
        printf '%s\n' "$session_pid" >"$SESSION_PID_FILE"

        for _ in $(seq 1 20); do
          if [[ -s "$RECORDER_PID_FILE" ]]; then
            notify "Recording…"
            exit 0
          fi
          if ! is_alive "$session_pid"; then
            notify "Error: recording failed to start"
            exit 1
          fi
          sleep 0.05
        done

        notify "Error: recording startup timed out"
        kill "$session_pid" 2>/dev/null || true
        exit 1
      '';
    })
  ];
}
