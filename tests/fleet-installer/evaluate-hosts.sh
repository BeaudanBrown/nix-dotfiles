#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

for module in modules/system/disko/*.nix; do
	host=$(basename "$module" .nix)
	case "$host" in
	btrfs | btrfs_2_drives | btrfs_luks | nas) continue ;;
	esac
	[[ -d hosts/$host ]] || continue
	printf 'evaluating installable host %s... ' "$host"
	timeout --signal=TERM --kill-after=5s 2m \
		nix eval --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" \
		>/dev/null
	echo ok
done
