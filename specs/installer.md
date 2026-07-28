# Encrypted Fleet Installer Specification

## Overview

The fleet installer is a writable, fleet-generic NixOS installation on a
LUKS2-encrypted USB. It replaces the legacy ISO and remote two-stage bootstrap
workflow.

The supported interface is:

```bash
# On an existing work host
just installer-usb

# After booting and unlocking the USB
install-host
```

The USB selects a host after boot, rotates its host and user Age identities,
asks NAS to rekey SOPS, partitions the declared Disko devices, and installs the
complete host configuration directly. There is no intermediate minimal target
installation or post-install rebuild.

## Security Model

The USB uses:

- an unencrypted EFI System Partition containing only boot artifacts;
- a LUKS2 volume containing an ext4 installer root;
- a passphrase entered during provisioning and on every boot;
- root-only NetworkManager profiles generated from selected WPA Personal
  SSID/PSK credentials;
- a dedicated persistent Headscale pre-auth key;
- a selected SSH identity for Git and NAS access.

Secure Boot is out of scope. Anyone who knows the USB LUKS passphrase can access
its provisioning credentials.

The Headscale key is declared as:

```text
SOPS file: secrets/work.yaml
Secret:    headscale/installer_pre_auth
Runtime:   /run/secrets/headscale/installer_pre_auth
```

The installer logs out of Headscale before rebooting the target.

## USB Provisioning

`just installer-usb` runs as the normal user and invokes sudo only for disk
operations. It:

1. Requires a clean, pushed default branch.
2. Verifies the installer configuration, Headscale secret, SSH identity, and
   active WPA Personal profile before disk erasure.
3. Lists USB devices reported as removable and at least 32 GiB.
4. Requires a default-No destructive confirmation.
5. Prompts twice for the USB LUKS passphrase.
6. Creates a GPT disk with a FAT EFI partition and LUKS2/ext4 root.
7. Installs `nixosConfigurations.installer`.
8. Copies the clean dotfiles clone, Wi-Fi profiles, Headscale key, and selected
   SSH identity into the encrypted root.

The installer system includes Zsh, Starship, Nixvim, tmux, NetworkManager with
`nmtui`, OpenSSH, Git, Disko, SOPS, Age, and the `fleet-installer` Go command.
It automatically logs into the restricted `installer` console account.

## Host Installation

`install-host`:

1. Fast-forwards the encrypted USB's dotfiles clone.
2. Evaluates only isolated Disko modules to discover eligible x86_64 hosts.
3. Suggests hosts whose declared `/dev/disk/by-id` devices exist.
4. Refuses missing devices, NAS, non-x86 hosts, and the installer USB itself.
5. Optionally overwrites `hosts/<host>/hardware.nix` using
   `nixos-generate-config --no-filesystems`.
6. Prompts twice for a target LUKS password when required.
7. Shows one consolidated default-No confirmation.
8. Generates a new SSH host identity and new Age key for every configured user.
9. Updates `all-hosts.json` and sends generated `.sops.yaml` recipients to the
   NAS helper.
10. Updates the exact `sopsSecrets` lock, commits, and pushes dotfiles.
11. Runs Disko and seeds host keys, user Age keys, Wi-Fi profiles, and dotfiles
    under `/mnt`.
12. Runs the complete selected host through `nixos-install --no-root-password`.
13. Copies redacted logs, creates a UEFI boot entry, sets `BootNext`, logs out of
    Headscale, and reboots after a cancellable ten-second countdown.

A failed invocation is not resumed. Rerunning starts the complete workflow from
scratch.

## NAS Rekey Helper

`modules/scripts/fleet-installer/nas.nix` installs
`installer-sops-rekey` on NAS. It runs as `beau` without sudo and:

1. Takes an exclusive repository lock.
2. Requires the configured SOPS checkout to be clean and fast-forwardable.
3. Creates a temporary Git worktree.
4. Installs the supplied `.sops.yaml` and runs strict `sops updatekeys` over all
   managed YAML files.
5. Commits and pushes only after all files succeed.
6. Returns the resulting commit as JSON.

The USB does not carry the private SOPS checkout or master Age key. NAS is
excluded as an installation target because it hosts this helper.

## Validation

Fast validation:

```bash
just test-installer
```

This builds/tests the Go package, exercises the NAS helper against synthetic
SOPS and Git fixtures, and evaluates every inferred installable fleet host.

Rootless QEMU validation is split for fast iteration:

```bash
just test-installer-e2e-provision  # creates cached encrypted USB
just test-installer-e2e-install    # snapshots cache and installs target
just test-installer-e2e            # complete from-scratch path
```

The target phase verifies target LUKS unlock, Disko, direct `nixos-install`,
UEFI boot, SSH, hostname, and protected SOPS secret materialization. Commands
have explicit stage timeouts, SSH keepalives, PID cleanup, and retained logs
under `.pi/tmp/`.

The final acceptance test is a physical Grill installation performed by the
user.
