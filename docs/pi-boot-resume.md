# Pi Boot Resume

This repo supports a generic manual reboot debugging loop:

1. Edit `.pi/boot-prompt.md` to describe the current task and permissions.
2. Commit the current coherent changes before preparing a boot generation.
3. Run `nr` or other approved commands to prepare the next boot generation.
4. Manually reboot the machine.
5. On graphical login, the OnePlus Niri session starts Ghostty running `scripts/pi-boot-resume.sh`.
6. The script opens `pi -c` in this repository and sends the configured prompt to the most recent session.

This is intentionally task-agnostic. Change `.pi/boot-prompt.md` for audio, reboot debugging, hardware bring-up, or any other investigation.

Current constraint: software reboot is not reliable yet. Do not automate reboot loops until that is fixed; ask for a manual reboot when the next boot cycle is needed.
