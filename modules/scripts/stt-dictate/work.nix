{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "stt-dictate";
      runtimeInputs = with pkgs; [
        pipewire
        curl
        jq
        wl-clipboard
        wtype
        libnotify
        coreutils
        util-linux
      ];
      text = ''
        set -euo pipefail

        cmd=''${1:-}
        if [ -z "$cmd" ]; then
          echo "usage: stt-dictate toggle" >&2
          exit 2
        fi

        if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
          echo "XDG_RUNTIME_DIR is not set" >&2
          exit 1
        fi

        PID_FILE="$XDG_RUNTIME_DIR/stt-dictate.pid"
        WAV="$XDG_RUNTIME_DIR/stt-dictate.wav"
        LOCKFILE="$XDG_RUNTIME_DIR/stt-dictate.lock"

        notify() {
          local msg="$1"
          (notify-send "STT" "$msg" >/dev/null 2>&1) || true
        }

        with_lock() {
          # Use kernel-managed locking to avoid stale lock directories.
          # Backwards-compat: previous versions used a lock *directory* at this path.
          if [ -d "$LOCKFILE" ]; then
            if ! rmdir "$LOCKFILE" 2>/dev/null; then
              notify "Busy"
              exit 0
            fi
          fi
          exec 9>"$LOCKFILE"
          if ! flock -n 9; then
            notify "Busy"
            exit 0
          fi
        }

        unlock() {
          # Closing the FD releases the flock.
          exec 9>&- 2>/dev/null || true
        }

        is_alive() {
          local pid="$1"
          kill -0 "$pid" 2>/dev/null
        }

        start_recording() {
          rm -f "$PID_FILE"
          rm -f "$WAV"
          local rec_log
          rec_log="$XDG_RUNTIME_DIR/stt-dictate.pw-record.log"
          rm -f "$rec_log"

          notify "Recording…"

          # pw-record sample formats are like: s16 (not s16le)
          ( exec 9>&-; exec pw-record --rate 16000 --channels 1 --format s16 "$WAV" 2>"$rec_log" ) &
          local pid=$!
          echo "$pid" > "$PID_FILE"

          # Detect immediate failure (bad flags, no device, etc.)
          sleep 0.15
          if ! is_alive "$pid"; then
            rm -f "$PID_FILE"
            msg="pw-record failed to start"
            if [ -s "$rec_log" ]; then
              last="$(tail -n 1 "$rec_log" 2>/dev/null || true)"
              if [ -n "$last" ]; then
                msg="$msg: $last"
              fi
            fi
            notify "Error: $msg"
            exit 1
          fi
        }

        stop_recording() {
          local pid
          pid="$(cat "$PID_FILE" 2>/dev/null || true)"
          if [ -z "$pid" ] || ! is_alive "$pid"; then
            rm -f "$PID_FILE"
            notify "Error: recorder not running"
            exit 1
          fi

          # Ask pw-record to stop cleanly.
          kill -INT "$pid" 2>/dev/null || true

          # Wait briefly; escalate if needed.
          for _ in $(seq 1 20); do
            if ! is_alive "$pid"; then
              break
            fi
            sleep 0.05
          done

          if is_alive "$pid"; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 0.2
          fi

          if is_alive "$pid"; then
            kill -KILL "$pid" 2>/dev/null || true
          fi

          rm -f "$PID_FILE"

          if [ ! -s "$WAV" ]; then
            notify "Error: no audio captured"
            exit 1
          fi
        }

        transcribe_and_paste() {
          notify "Transcribing…"

          resp="$(
            curl -fsS \
              --connect-timeout 2 \
              --max-time 30 \
              "https://stt.bepis.lol/inference" \
              -H "Content-Type: multipart/form-data" \
              -F "file=@$WAV" \
              -F "temperature=0.0" \
              -F "temperature_inc=0.0" \
              -F "response_format=json"
          )" || {
            notify "Error: upload/transcribe failed"
            exit 1
          }

          text="$(
            printf %s "$resp" \
              | jq -r '(.text // .transcription // .data.text // .result.text // empty)'
          )" || text=""

          if [ -z "$text" ]; then
            dbg="$XDG_RUNTIME_DIR/stt-dictate.response.json"
            printf %s "$resp" > "$dbg"
            notify "Error: empty transcript (saved response)"
            exit 1
          fi

          # Populate both clipboards:
          # - Clipboard: used by Ctrl+V / apps
          # - Primary selection: used by middle-click / Shift+Insert in many apps
          printf %s "$text" | wl-copy
          printf %s "$text" | wl-copy --primary

          # Best-effort paste into focused application.
          # Ctrl+Shift+V is more reliable than Ctrl+V in terminals/Vim.
          wtype -M ctrl -M shift -k v -m shift -m ctrl
        }

        case "$cmd" in
          toggle)
            with_lock

            if [ -f "$PID_FILE" ]; then
              pid="$(cat "$PID_FILE" 2>/dev/null || true)"
              if [ -n "$pid" ] && is_alive "$pid"; then
                # Stop recording under lock, then release it so we don't block
                # subsequent toggles while transcribing.
                stop_recording
                unlock
                transcribe_and_paste
              else
                rm -f "$PID_FILE"
                start_recording
              fi
            else
              start_recording
            fi

            # If we didn't already unlock above, unlock now.
            unlock
            ;;
          *)
            echo "unknown command: $cmd" >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
