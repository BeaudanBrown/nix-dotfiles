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
