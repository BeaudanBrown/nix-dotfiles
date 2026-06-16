#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-loop-seed-reboot <ticket-id> [--epic <epic-id>] [--checks <text>] [--no-next-loop]

Seed .pi/boot-task.md for a one-shot OnePlus reboot validation handoff.
This helper writes prompt files only; it never commits, rebuilds, or reboots.
EOF
}

epic_id="nd-gv62"
checks=""
write_next_loop=1

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
	usage
	exit 0
fi

if [[ $# -lt 1 ]]; then
	usage >&2
	exit 2
fi

ticket_id="$1"
shift

while [[ $# -gt 0 ]]; do
	case "$1" in
	--epic)
		[[ $# -ge 2 ]] || {
			echo "--epic requires an id" >&2
			exit 2
		}
		epic_id="$2"
		shift 2
		;;
	--checks)
		[[ $# -ge 2 ]] || {
			echo "--checks requires text" >&2
			exit 2
		}
		checks="$2"
		shift 2
		;;
	--no-next-loop)
		write_next_loop=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

repo_dir="$(git rev-parse --show-toplevel)"
cd "$repo_dir"

commit_hash="$(git rev-parse HEAD)"
short_hash="$(git rev-parse --short HEAD)"
task_file="${PI_BOOT_RESUME_TASK_PROMPT:-$repo_dir/.pi/boot-task.md}"
next_loop_file="${PI_BOOT_RESUME_NEXT_LOOP:-$repo_dir/.pi/boot-next-loop.md}"

mkdir -p "$(dirname "$task_file")" "$(dirname "$next_loop_file")"

if [[ -z $checks ]]; then
	checks="Assess the ticket-specific runtime behavior that required this reboot; inspect current boot logs, failed units, display/input/audio state as relevant, and compare against the expectations recorded on ${ticket_id}."
fi

cat >"$task_file" <<EOF
Post-reboot validation for OnePlus ticket ${ticket_id}.

Commit under test: ${commit_hash} (${short_hash})
Loop root: ${epic_id}

Do not reboot again automatically. This is a one-shot reboot validation handoff.

Required first steps:
1. Read docs/oneplus-loop-bootstrap.md.
2. Inspect git/tk state:
   - git status --short
   - tk show ${epic_id}
   - tk show ${ticket_id}
   - git show --stat ${commit_hash}
3. Validate the reboot result:
   ${checks}
4. Add a tk note to ${ticket_id} with PASS/FAIL evidence and remaining risk.
5. If the change failed, revert/amend/create follow-up work as appropriate before continuing.
6. If the result is validated and more work remains, use the optional next-loop instruction below. Do not start another reboot unless a later ticket explicitly seeds a new one-shot handoff.
EOF

if [[ $write_next_loop -eq 1 ]]; then
	cat >"$next_loop_file" <<EOF
Optional next-loop instruction after post-boot validation:

If runtime evidence is recorded, the worktree is clean, and no blocker remains, continue with exactly one fresh-agent iteration:

/aloop 1 ${epic_id}

Do not run this before validating ticket ${ticket_id} and commit ${commit_hash}.
EOF
	printf 'Updated %s and %s for ticket %s at %s\n' "$task_file" "$next_loop_file" "$ticket_id" "$short_hash"
else
	rm -f "$next_loop_file"
	printf 'Updated %s for ticket %s at %s; removed %s\n' "$task_file" "$ticket_id" "$short_hash" "$next_loop_file"
fi
