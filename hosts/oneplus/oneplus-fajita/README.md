# OnePlus 6T Fajita

This directory contains the board-specific bring-up for the OnePlus 6T
(`oneplus-fajita`). The flake-discovered host remains `hosts/oneplus`.

## Layout

- `system.nix`: top-level phone module imported by `hosts/oneplus/default.nix`.
- `hardware/`: SDM845 kernel, firmware, device tree, initrd, and Qualcomm services.
- `image/`: repart-based image layout.
- `networking/`: NetworkManager, iwd, Tailscale, and firewall settings.
- `ui/`: Phosh/mobile user interface configuration.
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

The active image is expected to be:

```text
/EFI/Linux/nixos.efi
```

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
