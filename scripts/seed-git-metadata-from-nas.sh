#!/usr/bin/env bash
# Seed local Syncthing Git metadata on clients from the canonical NAS copies.
#
# Run this on NAS while .git remains ignored by Syncthing and Git is quiescent.
# It previews by default; pass --apply followed by one or more SSH host aliases.
set -euo pipefail

apply=false
if [[ ${1:-} == "--apply" ]]; then
	apply=true
	shift
fi

if (($# == 0)); then
	echo "usage: $0 [--apply] HOST [HOST ...]" >&2
	exit 2
fi

hosts=("$@")
roots=(documents monash collab)
timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"

die() {
	echo "$*" >&2
	exit 1
}

is_local() {
	local target="$1"
	local fstype

	fstype="$(stat -f --format='%T' -- "$target")"
	[[ $fstype != "nfs" && $fstype != "nfs4" && $fstype != "autofs" ]]
}

check_host() {
	local host="$1"
	local root="$2"
	local destination_root="/home/beau/$root"

	[[ $host =~ ^[[:alnum:]._-]+$ ]] || die "invalid SSH host alias: $host"

	ssh "$host" bash -s -- "$destination_root" <<'EOF'
set -euo pipefail

target="$1"
[[ -d "$target" ]] || {
  echo "missing destination root: $target" >&2
  exit 1
}

fstype="$(stat -f --format='%T' -- "$target")"
case "$fstype" in
  nfs|nfs4|autofs)
    echo "destination is not local ($fstype): $target" >&2
    exit 1
    ;;
esac
EOF
}

backup_remote_git_metadata() {
	local host="$1"
	local destination="$2"

	ssh "$host" bash -s -- "$destination" "$timestamp" <<'EOF'
set -euo pipefail

destination="$1"
timestamp="$2"
mkdir -p -- "$(dirname -- "$destination")"

if [[ -e "$destination" || -L "$destination" ]]; then
  backup="${destination}.pre-nas-git-${timestamp}"
  printf '  backing up %s -> %s\n' "$destination" "$backup"
  mv -- "$destination" "$backup"
fi
EOF
}

seed_git_metadata() {
	local host="$1"
	local source="$2"
	local destination="$3"
	local kind="$4"

	printf '%s .git: %s -> %s:%s\n' "$kind" "$source" "$host" "$destination"
	if [[ $apply == false ]]; then
		return
	fi

	backup_remote_git_metadata "$host" "$destination"

	if [[ $kind == "directory" ]]; then
		rsync -a --whole-file --protect-args -- "$source/" "$host:$destination/"
	else
		rsync -a --whole-file --protect-args -- "$source" "$host:$destination"
	fi
}

for root in "${roots[@]}"; do
	source_root="$HOME/$root"
	[[ -d $source_root ]] || die "missing NAS source root: $source_root"
	is_local "$source_root" || die "NAS source is not local: $source_root"

	# Do not descend into a found .git directory: preview should not enumerate Git
	# objects, and rsync will copy them after the mapping has been approved.
	mapfile -d '' -t git_entries < <(find "$source_root" -name .git -print0 -prune)
	printf 'Found %d Git metadata entr%s under %s.\n' \
		"${#git_entries[@]}" \
		"$([[ ${#git_entries[@]} == 1 ]] && echo y || echo ies)" \
		"$source_root"

	for host in "${hosts[@]}"; do
		check_host "$host" "$root"
	done

	for source in "${git_entries[@]}"; do
		relative="${source#"$source_root/"}"
		if [[ -d $source ]]; then
			kind="directory"
		elif [[ -f $source ]]; then
			kind="file"
		else
			die "refusing unsupported .git entry: $source"
		fi

		for host in "${hosts[@]}"; do
			seed_git_metadata "$host" "$source" "/home/beau/$root/$relative" "$kind"
		done
	done
done

if [[ $apply == false ]]; then
	echo "Preview only. Review the mappings, then rerun with --apply and the same hosts."
fi
