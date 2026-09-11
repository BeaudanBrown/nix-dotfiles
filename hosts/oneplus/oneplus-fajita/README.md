# OnePlus 6T Fajita

This directory contains the board-specific configuration for the OnePlus 6T (`oneplus-fajita`). The flake-discovered host remains `hosts/oneplus`.

For Android restoration and returning to U-Boot/NixOS, start with
[the round-trip preparation runbook](../../../docs/oneplus-android-roundtrip.md).
It records published source, U-Boot generation/flashing, and remaining NixOS
reconstruction gaps; it is not yet a validated end-to-end restore procedure.

For agent-facing current state and workflow, start with:

- `docs/oneplus-loop-bootstrap.md`
- `docs/oneplus-bringup.md`
- `docs/oneplus-agent-loop.md`
- `docs/oneplus-debug-tools.md`

## Layout

- `system.nix`: top-level phone module imported by `hosts/oneplus/default.nix`.
- `hardware/`: SDM845 kernel, firmware, device tree, initrd, and Qualcomm services.
- `image/`: repart-based image layout.
- `networking/`: NetworkManager, iwd, Tailscale, and firewall settings.
- `ui/`: current mobile UI/session configuration, including Niri/Ghostty boot-resume and touch/gesture helpers.
- `packages/`: U-Boot and boot image derivations.
- `assets/`: DTS, kernel config, and U-Boot input files used by active modules.

Password-based debug access is intentionally not configured here. SSH keys are
kept in the active system module and OpenSSH is configured for key-only access.

## U-Boot fsck recovery

If the phone fails to boot with an fsck error after an unclean shutdown, the
U-Boot USB ACM serial gadget can be used to run a one-shot repair. This does not
modify U-Boot environment permanently as long as `saveenv` is not run.

From the U-Boot prompt, first confirm the nested NixOS disk and UKI are visible:

```text
run setup_nixos_blkmap
fatls blkmap 0:2 /EFI/Linux/
```

These direct-UKI fsck-recovery commands expect this file to exist:

```text
/EFI/Linux/nixos.efi
```

It is not necessarily the current generation. The normal `boot_nixos` command
loads `/EFI/BOOT/BOOTAA64.EFI` (systemd-boot), which selects a generation from
`/loader/entries/`. Check the UKI exists before using this recovery shortcut;
do not mistake it for the normal active boot entry.

To force fsck repair, paste this command block:

```text
run setup_nixos_blkmap
setenv bootargs 'console=ttyGS0,115200 clk_ignore_unused pd_ignore_unused arm64.nopauth console=ttyMSM0,115200n8 console=tty0 rd.systemd.default_standard_output=kmsg+console rd.systemd.default_standard_error=kmsg+console rd.systemd.journald.forward_to_console=1 rd.systemd.log_target=console rd.systemd.journald.forward_to_console=1 root=fstab loglevel=8 lsm=landlock,yama,bpf fsck.mode=force fsck.repair=yes'
fatload blkmap 0:2 ${efi_addr_r} /EFI/Linux/nixos.efi
bootefi ${efi_addr_r} ${fdtcontroladdr}
```

Expected outcome:

- fsck may report that the filesystem was modified.
- The direct boot may later stop with a message like `no init= parameter on the
  kernel command line`. That is expected for this recovery path: the temporary
  `bootargs` override the NixOS UKI's embedded `init=/nix/store/.../init`
  argument.
- After fsck has repaired the filesystem, reboot and use the normal boot path:

```text
reset
```

Alternatively, clear the temporary `bootargs` and boot NixOS without resetting:

```text
setenv bootargs
run boot_nixos
```

To skip fsck temporarily while preserving the known-good OnePlus kernel
parameters, use the same commands but replace the fsck arguments with
`fsck.mode=skip`:

```text
run setup_nixos_blkmap
setenv bootargs 'console=ttyGS0,115200 clk_ignore_unused pd_ignore_unused arm64.nopauth console=ttyMSM0,115200n8 console=tty0 rd.systemd.default_standard_output=kmsg+console rd.systemd.default_standard_error=kmsg+console rd.systemd.journald.forward_to_console=1 rd.systemd.log_target=console rd.systemd.journald.forward_to_console=1 root=fstab loglevel=8 lsm=landlock,yama,bpf fsck.mode=skip'
fatload blkmap 0:2 ${efi_addr_r} /EFI/Linux/nixos.efi
bootefi ${efi_addr_r} ${fdtcontroladdr}
```

Notes:

- Do not run `saveenv` while using these temporary boot arguments.
- U-Boot's USB ACM serial gadget disconnects when Linux takes over; this is
  normal and is not the same as a Linux emergency shell.
- UMS cannot usually be started while the same USB gadget is being used as the
  only interactive console. If real UART is available, UMS can be used to expose
  the nested disk to another Linux host and run `e2fsck` there.
