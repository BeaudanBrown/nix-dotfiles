#!/usr/bin/env bash
if [ $# -eq 0 ]; then
	echo "Usage: get packet1 packet2 packet3 ..."
	exit 1
fi

extension=""

for pkg in "$@"; do
	extension="$extension nixpkgs#$pkg"
done

cmd="nix shell$extension"

echo "Executing: $cmd"
eval "$cmd"
