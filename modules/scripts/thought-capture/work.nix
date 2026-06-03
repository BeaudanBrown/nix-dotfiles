{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "thought-capture";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        jq
        libnotify
        pipewire
        util-linux
      ];
      text = ''
        set -euo pipefail

        cmd=''${1:-}
        if [ -z "$cmd" ]; then
          echo "usage: thought-capture toggle|status" >&2
          exit 2
        fi

        if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
          echo "XDG_RUNTIME_DIR is not set" >&2
          exit 1
        fi

        SERVER_URL="''${THOUGHT_CAPTURE_URL:-http://grill.lan:8787}"
        PID_FILE="$XDG_RUNTIME_DIR/thought-capture.pid"
        WAV="$XDG_RUNTIME_DIR/thought-capture.wav"
        LOCKFILE="$XDG_RUNTIME_DIR/thought-capture.lock"

        notify() {
          local msg="$1"
          (notify-send "Thought Capture" "$msg" >/dev/null 2>&1) || true
        }

        with_lock() {
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
          exec 9>&- 2>/dev/null || true
        }

        is_alive() {
          local pid="$1"
          kill -0 "$pid" 2>/dev/null
        }

        start_recording() {
          rm -f "$PID_FILE" "$WAV"
          local rec_log
          rec_log="$XDG_RUNTIME_DIR/thought-capture.pw-record.log"
          rm -f "$rec_log"

          notify "Recording thought…"

          ( exec 9>&-; exec pw-record --rate 16000 --channels 1 --format s16 "$WAV" 2>"$rec_log" ) &
          local pid=$!
          echo "$pid" > "$PID_FILE"

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

          kill -INT "$pid" 2>/dev/null || true

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

        upload_capture() {
          notify "Uploading thought…"

          local source_host
          source_host="$(cat /proc/sys/kernel/hostname 2>/dev/null || printf unknown)"

          local resp
          resp="$(
            curl -fsS \
              --connect-timeout 3 \
              --max-time 180 \
              "$SERVER_URL/api/captures/audio" \
              -F "file=@$WAV" \
              -F "source=thought-capture" \
              -F "source_host=$source_host"
          )" || {
            rm -f "$WAV"
            notify "Error: upload/process failed"
            exit 1
          }

          rm -f "$WAV"

          local title summary
          title="$(printf %s "$resp" | jq -r '.capture.title // .capture.id // "captured"')"
          summary="$(printf %s "$resp" | jq -r '.capture.summary // empty')"

          if [ -n "$summary" ]; then
            notify "Captured: $title"
            printf '%s\n\n%s\n' "$title" "$summary"
          else
            notify "Captured: $title"
            printf '%s\n' "$title"
          fi
        }

        case "$cmd" in
          toggle)
            with_lock

            if [ -f "$PID_FILE" ]; then
              pid="$(cat "$PID_FILE" 2>/dev/null || true)"
              if [ -n "$pid" ] && is_alive "$pid"; then
                stop_recording
                unlock
                upload_capture
              else
                rm -f "$PID_FILE"
                start_recording
              fi
            else
              start_recording
            fi

            unlock
            ;;
          status)
            curl -fsS "$SERVER_URL/health" | jq .
            ;;
          *)
            echo "unknown command: $cmd" >&2
            exit 2
            ;;
        esac
      '';
    })

    (pkgs.writeShellApplication {
      name = "thoughts";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        jq
        xdg-utils
      ];
      text = ''
        set -euo pipefail

        SERVER_URL="''${THOUGHT_CAPTURE_URL:-http://grill.lan:8787}"
        cmd="''${1:-recent}"
        if [ "$#" -gt 0 ]; then
          shift
        fi

        print_captures() {
          jq -r '
            .captures[]? |
            [
              (.created_at // ""),
              (.title // .id // "Untitled thought"),
              (.summary // ""),
              (.importance // "medium"),
              ((.tags // []) | join(","))
            ] | @tsv
          ' | while IFS=$'\t' read -r created title summary importance tags; do
            printf '%s  [%s]\n' "$created" "$importance"
            printf '  %s\n' "$title"
            if [ -n "$summary" ]; then
              printf '  %s\n' "$summary"
            fi
            if [ -n "$tags" ]; then
              printf '  tags: %s\n' "$tags"
            fi
            printf '\n'
          done
        }

        case "$cmd" in
          recent)
            limit="''${1:-10}"
            curl -fsS "$SERVER_URL/api/recent?limit=$limit" | print_captures
            ;;
          search)
            if [ "$#" -eq 0 ]; then
              echo "usage: thoughts search <query>" >&2
              exit 2
            fi
            query="$*"
            curl -fsS --get \
              --data-urlencode "q=$query" \
              --data-urlencode "limit=''${THOUGHTS_LIMIT:-20}" \
              "$SERVER_URL/api/search" | print_captures
            ;;
          health|status)
            curl -fsS "$SERVER_URL/health" | jq .
            ;;
          open)
            xdg-open "$SERVER_URL/" >/dev/null 2>&1 || printf '%s\n' "$SERVER_URL/"
            ;;
          *)
            echo "usage: thoughts recent [limit] | search <query> | open | health" >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
