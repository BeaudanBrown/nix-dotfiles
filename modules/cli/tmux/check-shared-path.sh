#!/usr/bin/env bash
# Reproduce the restricted service PATH; do not touch the live tmux server.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
service_path=${1:-$(tmux show-environment -g PATH)}
service_path=${service_path#PATH=}
# shellcheck disable=SC2016 # $1 is expanded in the isolated child shell.
env -i "HOME=$HOME" "PATH=$service_path" bash -c '
  source "$1/shared-path.sh"
  for command in tmux_project less fzf; do
    command -v "$command" >/dev/null || { echo "Missing from tmux server environment: $command" >&2; exit 1; }
  done
' _ "$here"
echo 'tmux service PATH includes host picker, pager and pinned boot tools: PASS'
