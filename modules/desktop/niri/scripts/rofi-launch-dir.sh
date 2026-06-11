#!/usr/bin/env bash
if [ "$#" -gt 0 ]; then
	coproc nautilus "$1" >/dev/null 2>&1
	exit 0
fi

cd "$HOME" || exit 1
fd -t d -d 5 --no-ignore --strip-cwd-prefix
