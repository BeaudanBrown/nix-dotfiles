Last boot/login is complete. Continue the current NixOS debugging task in this repository.

Boot-resume workflow:
- First read the task-specific seed below, then inspect current git state and relevant logs/runtime state.
- You may run non-destructive inspection commands.
- You may run `nr` to prepare the next boot generation.
- Before running `nr`, commit the current coherent changes so the booted generation corresponds to a durable git state.
- On this host, `nr` is expected to have passwordless access to its required `systemd-run` step.
- Software reboot is not reliable yet, so do not attempt automatic reboot loops.
- When a reboot is needed, stop after preparing the generation and ask the user to manually reboot.

Task-specific seed follows.
