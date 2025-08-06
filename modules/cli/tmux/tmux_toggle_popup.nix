{ pkgs, ... }:

let
  script = # bash
    ''
            #!/usr/bin/env bash
            set -euo pipefail

            die()  { echo "error: $*" >&2; exit 1; }
            usage() {
              cat <<EOF
      $(basename "$0") [OPTIONS] <session> [command]

      Options
        -n, --new-window   Open a new tmux window inside <session> (no popup)
        -f, --force        Always run <command>, never detach first
        -k, --keep         Keep window/pane open after <command> exits
      EOF
              exit 1
            }

            # ------------------------------------------------------------
            # Option parsing ------------------------------------------------
            # ------------------------------------------------------------
            opts=$(getopt -o nfk -l new-window,force,keep -- "$@") || usage
            eval set -- "$opts"

            new_window=0 force=0 keep=0
            while true; do
              case $1 in
                -n|--new-window) new_window=1 ;;
                -f|--force)      force=1 ;;
                -k|--keep)       keep=1 ;;
                --) shift; break ;;
              esac
              shift
            done

            [[ $# -ge 1 ]] || usage
            target="$1"; shift
            cmd=''${1-}          # empty means “no command”

            # ------------------------------------------------------------
            # Small helpers ------------------------------------------------
            # ------------------------------------------------------------
            curr_session=$(tmux display-message -p '#{session_name}')
            cwd=$(tmux display-message -p -t default: '#{pane_current_path}') \
              || die "Could not determine CWD from 'default' session"

            session_exists() { tmux has-session -t "$target" 2>/dev/null; }

            popup() {          # popup "<string that is evaluated by -E>"
              tmux display-popup -E -w 95% -h 95% "$*"
            }

            new_session_cmd() {
              local extra=''${1-}
              printf 'tmux new-session -A -s "%s" -c "%s"%s' \
                     "$target" "$cwd" "''${extra:+ \"$extra\"}"
            }

            run_in_session() {     # send $cmd to already-attached session
              [[ -n $cmd ]] || return
              tmux send-keys -t "$target" C-c
              sleep 0.1
              tmux send-keys -t "$target" "$cmd" Enter
            }

            # remember last scratch name (unchanged behaviour)
            tmux set -gF '@last_scratch_name' "$target"

            # ------------------------------------------------------------
            # MAIN LOGIC --------------------------------------------------
            # ------------------------------------------------------------

            # 1) — “open a new window” mode --------------------------------
            if (( new_window )); then
              # ensure we are attached to the right session (via popup)
              if [[ $curr_session != "$target" ]]; then
                [[ $curr_session != "default" ]] && tmux detach-client
                popup "$(new_session_cmd)"
              fi

              # create the new window
              if [[ -z $cmd ]]; then
                tmux new-window -c "$cwd"
              else
                tail=''${keep:+; exec $SHELL}
                tmux new-window -c "$cwd" "$cmd$tail"
              fi
              exit                        # done
            fi

            # 2) — “toggle” (detach) behaviour -----------------------------
            if ! (( force )); then
              if [[ $curr_session == "$target" ]]; then
                tmux detach-client; exit
              fi
              [[ $curr_session != "default" ]] && tmux detach-client
            fi

            # 3) — already inside session + --force => just run command ----
            if (( force )) && session_exists && [[ $curr_session == "$target" ]]; then
              run_in_session; exit
            fi

            # 4) — open / create popup -------------------------------------
            extra=""
            if [[ -n $cmd ]]; then
              extra=$cmd
              (( keep )) && extra="$extra; exec \$SHELL"
            fi
            popup "$(new_session_cmd "$extra")"

            # 5) — after popup is open, maybe send command -----------------
            if (( force )) && session_exists; then
              run_in_session
            fi
    '';

in
pkgs.writeShellApplication {
  name = "tmux_toggle_popup";
  runtimeInputs = [ pkgs.tmux ];
  text = script;
}
