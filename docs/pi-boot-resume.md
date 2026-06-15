# Pi Boot Resume

This repo supports a generic manual reboot debugging loop.

## Files

- `.pi/boot-system.md` is tracked and contains the persistent boot-resume operating instructions.
- `.pi/boot-task.md` is intentionally untracked/ignored and contains the current task seed. Edit this file to change what pi should continue after the next manual reboot.
- `scripts/pi-boot-resume.sh` opens/attaches the `default` tmux session, starts a `pi-boot-resume` tmux window, concatenates the system prompt and task seed, then opens the most recently modified Pi session and sends the prompt there.

## Workflow

1. Seed the current debugging task with either `scripts/pi-boot-seed.sh "continue ..."` or by editing `.pi/boot-task.md`.
2. Commit the current coherent changes before preparing a boot generation.
3. Run `nr` or other approved commands to prepare the next boot generation. Do not run `nix eval` immediately before `nr`; it duplicates work.
4. Manually reboot the machine.
5. On graphical login, the OnePlus Niri session starts Ghostty running `scripts/pi-boot-resume.sh`.
6. The script attaches Ghostty to the `default` tmux session, recreates the `pi-boot-resume` window, opens the newest Pi session under `~/.pi/agent/sessions` (or `$PI_BOOT_RESUME_SESSION_DIR` / `$PI_CODING_AGENT_SESSION_DIR`), and sends the combined prompt to it.

This is intentionally task-agnostic. Change `.pi/boot-task.md` for audio, reboot debugging, hardware bring-up, or any other investigation.

Current constraint: software reboot is not reliable yet. Do not automate reboot loops until that is fixed; ask for a manual reboot when the next boot cycle is needed.

On the OnePlus host, `wheel` currently has temporary passwordless sudo for bring-up/debugging. The resumed agent may use `sudo` freely for root-only diagnostics on this host. Remove `security.sudo.wheelNeedsPassword = false;` from `hosts/oneplus/oneplus-fajita/system.nix` once the OnePlus system is stable overall.
