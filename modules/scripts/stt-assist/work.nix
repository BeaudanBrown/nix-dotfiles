{ pkgs, ... }:
let
  # Prefetch the Piper voice model at build time (like the NAS whisper model).
  # NOTE: the hashes below are placeholders. Build once and replace with the
  # hashes Nix prints on the failure.
  # voiceOnnx = pkgs.fetchurl {
  #   url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
  #   hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
  # };
  # voiceJson = pkgs.fetchurl {
  #   url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
  #   hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
  # };

  voiceOnnx = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx";
    hash = "sha256-0R5AOgK99aZwyHez3Fbg4cjOzm+zAolYYxTf/cCnjLA=";
  };
  voiceJson = pkgs.fetchurl {
    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx.json";
    hash = "sha256-9mhHQkrtC/mey7XXz95HwKkG9Cag2vfEbzBefSGv2IY=";
  };

  piperVoiceDir = pkgs.runCommand "piper-voice" { } ''
    mkdir -p "$out"
    ln -s ${voiceOnnx} "$out/en_US-hfc_male-medium.onnx"
    ln -s ${voiceJson} "$out/en_US-hfc_male-medium.onnx.json"
  '';
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "stt-assist";
      runtimeInputs = with pkgs; [
        pipewire
        curl
        jq
        wl-clipboard
        wtype
        libnotify
        coreutils
        piper-tts
        util-linux
      ];
      text = ''
        set -euo pipefail

        cmd=''${1:-}
        if [ -z "$cmd" ]; then
          echo "usage: stt-assist ask [--model <model>]" >&2
          exit 2
        fi

        if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
          echo "XDG_RUNTIME_DIR is not set" >&2
          exit 1
        fi

        # Configuration
        STT_URL="https://stt.bepis.lol/inference"
        ASSISTANT_URL="https://assistant.bepis.lol/ask"
        DEFAULT_MODEL="''${STT_ASSIST_MODEL:-gpt-5-mini}"

        PID_FILE="$XDG_RUNTIME_DIR/stt-assist.pid"
        WAV="$XDG_RUNTIME_DIR/stt-assist.wav"
        LOCKFILE="$XDG_RUNTIME_DIR/stt-assist.lock"
        TTS_WAV="$XDG_RUNTIME_DIR/stt-assist-tts.wav"

        notify() {
          local msg="$1"
          (notify-send "STT Assist" "$msg" >/dev/null 2>&1) || true
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
          rec_log="$XDG_RUNTIME_DIR/stt-assist.pw-record.log"
          rm -f "$rec_log"

          notify "Recording…"

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

        transcribe_audio() {
          notify "Transcribing…"

          local resp
          resp="$(
            curl -fsS \
              --connect-timeout 2 \
              --max-time 30 \
              "$STT_URL" \
              -H "Content-Type: multipart/form-data" \
              -F "file=@$WAV" \
              -F "temperature=0.0" \
              -F "temperature_inc=0.0" \
              -F "response_format=json"
          )" || {
            notify "Error: STT failed"
            exit 1
          }

          local text
          text="$(
            printf %s "$resp" \
              | jq -r '(.text // .transcription // .data.text // .result.text // empty)'
          )" || text=""

          if [ -z "$text" ]; then
            notify "Error: empty transcript"
            exit 1
          fi

          printf %s "$text"
        }

        query_assistant() {
          local transcript="$1"
          local model="$2"

          notify "Thinking…"

          local resp
          resp="$(
            curl -fsS \
              --connect-timeout 5 \
              --max-time 60 \
              "$ASSISTANT_URL" \
              -H "Content-Type: application/json" \
              -d "$(jq -n --arg text "$transcript" --arg model "$model" '{text: $text, model: $model, mode: "speak"}')"
          )" || {
            notify "Error: assistant request failed"
            exit 1
          }

          printf %s "$resp"
        }

        # Piper voice configuration (prefetched into the Nix store)
        PIPER_VOICE_MODEL="${piperVoiceDir}/en_US-hfc_male-medium.onnx"

        speak_response() {
          local text="$1"

          notify "Speaking…"

          # Generate TTS audio using Piper
          printf %s "$text" | piper \
            --model "$PIPER_VOICE_MODEL" \
            --output_file "$TTS_WAV" 2>/dev/null || {
            notify "Error: TTS failed"
            return 1
          }

          # Play the audio using pw-play (PipeWire)
          if [ -f "$TTS_WAV" ]; then
            pw-play "$TTS_WAV" 2>/dev/null || true
            rm -f "$TTS_WAV"
          fi
        }

        ask_assistant() {
          local model="$DEFAULT_MODEL"

          # Parse optional --model argument
          while [ $# -gt 0 ]; do
            case "$1" in
              --model)
                model="$2"
                shift 2
                ;;
              *)
                shift
                ;;
            esac
          done

          local transcript
          transcript="$(transcribe_audio)"

          local assistant_resp
          assistant_resp="$(query_assistant "$transcript" "$model")"

          local spoken text
          spoken="$(printf %s "$assistant_resp" | jq -r '.spoken // empty')"
          text="$(printf %s "$assistant_resp" | jq -r '.text // empty')"

          if [ -z "$text" ]; then
            notify "Error: empty response from assistant"
            exit 1
          fi

          # Always copy full text to clipboard
          printf %s "$text" | wl-copy
          printf %s "$text" | wl-copy --primary

          # Speak the spoken version
          if [ -n "$spoken" ]; then
            speak_response "$spoken"
          fi

          # Paste the full text into focused application
          wtype -M ctrl -M shift -k v -m shift -m ctrl

          notify "Done"
        }

        case "$cmd" in
          toggle)
            with_lock

            if [ -f "$PID_FILE" ]; then
              pid="$(cat "$PID_FILE" 2>/dev/null || true)"
              if [ -n "$pid" ] && is_alive "$pid"; then
                # Stop recording under lock, then release it so we don't block
                # subsequent toggles while transcribing/thinking/speaking.
                stop_recording
                unlock
                ask_assistant "$@"
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
