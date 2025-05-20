{ pkgs, ... }:

let
  script = # bash
    ''
      # Function to display usage
      usage() {
        echo "Usage: $(basename "$0") [-w|--per-window] <target_prefix> [init_command]"
        echo "  <target_prefix>: Prefix for the session name (e.g., 'gpt', 'scratch')."
        echo "  <init_command>: Command to run when a new session is created."
        echo "  -w, --per-window: Enable one session per 'default' session window."
        exit 1
      }

      PER_WINDOW_MODE=false
      FORCE_INIT=false

      while [[ $# -gt 0 ]]; do
        case "$1" in
          -w|--per-window)
          PER_WINDOW_MODE=true
          shift # past argument
          ;;
          -f|--force-init)
          FORCE_INIT=true
          shift
          ;;
          --) # End of all options
          shift # past argument
          break
          ;;
          -*) # Unknown option
          echo "Unknown option: $1"
          usage
          ;;
          *)  # Not an option, so it's the start of positional arguments
          break
          ;;
        esac
      done

      if [[ $# -lt 1 ]]; then
        echo "Error: Missing mandatory TARGET_SESSION argument."
        usage
      fi

      TARGET_SESSION="$1"
      shift

      # INIT_COMMAND is optional; default to empty string if not provided.
      if [[ $# -gt 0 ]]; then
        INIT_COMMAND="$1"
        shift
      else
        INIT_COMMAND=""
      fi

      CURRENT_SESSION_NAME=$(tmux display-message -p '#{session_name}')
      DEFAULT_SESSION_CWD=$(tmux display-message -p -t default: '#{pane_current_path}')

      if [ -z "$DEFAULT_SESSION_CWD" ]; then
        tmux display-message "Error: Could not get CWD from 'default' session. Ensure 'default' session exists and has an active pane."
        exit 1
      fi

      TARGET_SESSION_NAME=""
      if [ "$PER_WINDOW_MODE" = true ]; then
        DEFAULT_SESSION_ACTIVE_WINDOW_INDEX=$(tmux display-message -p -t default: '#{window_index}')
        if [ -z "$DEFAULT_SESSION_ACTIVE_WINDOW_INDEX" ]; then
          tmux display-message "Error: Per-window mode enabled, but could not get active window index from 'default' session."
          exit 1
        fi
        TARGET_SESSION_NAME="''${TARGET_SESSION}-''${DEFAULT_SESSION_ACTIVE_WINDOW_INDEX}"
      else
        TARGET_SESSION_NAME="''${TARGET_SESSION}"
      fi

      tmux set -gF '@last_scratch_name' "$TARGET_SESSION_NAME"

      if [ "$CURRENT_SESSION_NAME" = "$TARGET_SESSION_NAME" ]; then
        tmux detach-client
        exit 0
      fi

      if [ "$CURRENT_SESSION_NAME" != "default" ]; then
        tmux detach-client
      fi

      if [ -z "$INIT_COMMAND" ]; then
        TMUX_COMMAND_FOR_POPUP="tmux new-session -A -s \"''${TARGET_SESSION_NAME}\" -c \"''${DEFAULT_SESSION_CWD}\""
      else
        TMUX_COMMAND_FOR_POPUP="tmux new-session -A -s \"''${TARGET_SESSION_NAME}\" -c \"''${DEFAULT_SESSION_CWD}\" \"''${INIT_COMMAND}\""
      fi

      if $FORCE_INIT && [[ -n "$INIT_COMMAND" ]]; then
        tmux send-keys -t "$TARGET_SESSION_NAME" C-c
        sleep 0.1
        tmux send-keys -t "$TARGET_SESSION_NAME" "$INIT_COMMAND" Enter
      fi

      tmux display-popup -E -w 95% -h 95% "''${TMUX_COMMAND_FOR_POPUP}"
    '';

in

pkgs.writeShellApplication {
  name = "tmux_toggle_popup";
  runtimeInputs = [ pkgs.tmux ];
  text = script;
}
