#!/usr/bin/env bash
set -euo pipefail

die() {
	echo "error: $*" >&2
	exit 1
}
usage() {
	cat <<EOF
$(basename "$0") [OPTIONS] <session> [command]

Options
  -n, --new-window   Open a new tmux window inside <session> (no popup)
  -f, --force        Always run <command>, never detach first
  -k, --keep         Keep window/pane open after <command> exits
      --split-right  Create a right-side pane running the given command
  -u, --unique       Make the session name (likely) unique
EOF
	exit 1
}

opts=$(getopt -o nfku -l new-window,force,keep,split-right:,unique -- "$@") || usage
eval set -- "$opts"

new_window=0 force=0 keep=0 split_right="" unique_session=0
while true; do
	case $1 in
	-n | --new-window) new_window=1 ;;
	-f | --force) force=1 ;;
	-k | --keep) keep=1 ;;
	--split-right)
		split_right=$2
		shift
		;;
	-u | --unique) unique_session=1 ;;
	--)
		shift
		break
		;;
	esac
	shift
done

[[ $# -ge 1 ]] || usage
target="$1"

shift
cmd=${1-}

curr_session=$(tmux display-message -p '#{session_name}')
cwd=$(tmux display-message -p -t default: '#{pane_current_path}') || die "Could not determine CWD from 'default' session"

if ((unique_session)); then
	last_dir="${cwd##*/}"
	target="$target-$last_dir"
fi

session_exists() { tmux has-session -t "=$target" 2>/dev/null; }

popup() {
	tmux display-popup -E -w 95% -h 95% "$*"
}

new_session_cmd() {
	local extra=${1-}
	printf 'tmux -T extkeys new-session -A -s "%s" -c "%s"%s' \
		"$target" "$cwd" "${extra:+ \"$extra\"}"
}

run_in_session() {
	[[ -n $cmd ]] || return
	local pane=${1:-$target}
	local interrupt=${2:-1}
	if ((interrupt)); then
		tmux send-keys -t "$pane" C-c
		sleep 0.1
	fi
	tmux send-keys -t "$pane" "$cmd" Enter
}

first_pane() {
	tmux list-panes -t "=$target:" -F '#{pane_id}' | head -n 1
}

ensure_split_session() {
	local left_pane

	if session_exists; then
		first_pane
		return
	fi

	left_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$target" -c "$cwd")
	tmux split-window -h -t "$left_pane" -c "$cwd" "$split_right" >/dev/null
	tmux select-pane -t "$left_pane"
	printf '%s\n' "$left_pane"
}

tmux set -gF '@last_scratch_name' "$target"

if ((new_window)); then
	if [[ $curr_session != "$target" ]]; then
		[[ $curr_session != "default" ]] && tmux detach-client
		popup "$(new_session_cmd)"
	fi
	if [[ -z $cmd ]]; then
		tmux new-window -c "$cwd"
	else
		tail=${keep:+; exec $SHELL}
		tmux new-window -c "$cwd" "$cmd$tail"
	fi
	exit
fi

if [[ -n $split_right ]]; then
	if ! ((force)); then
		if [[ $curr_session == "$target" ]]; then
			tmux detach-client
			exit
		fi
		[[ $curr_session != "default" ]] && tmux detach-client
	fi

	existed_before=0
	session_exists && existed_before=1
	left_pane=$(ensure_split_session)

	if ((force)) && [[ $curr_session == "$target" ]]; then
		run_in_session "$left_pane"
		exit
	fi

	if [[ -n $cmd ]] && { ((!existed_before)) || ((force)); }; then
		run_in_session "$left_pane" "$existed_before"
	fi

	popup "$(new_session_cmd)"
	exit
fi

if ! ((force)); then
	if [[ $curr_session == "$target" ]]; then
		tmux detach-client
		exit
	fi
	[[ $curr_session != "default" ]] && tmux detach-client
fi

if ((force)) && session_exists && [[ $curr_session == "$target" ]]; then
	run_in_session
	exit
fi

extra=""
if [[ -n $cmd ]]; then
	extra=$cmd
	((keep)) && extra="$extra; exec \$SHELL"
fi
popup "$(new_session_cmd "$extra")"

if ((force)) && session_exists; then
	run_in_session
fi
