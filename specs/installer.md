# NixOS Installer Specification

## Overview

The repository includes a custom NixOS installer configuration for bootstrapping new machines. This provides:
- Pre-configured SSH access for remote installation
- Tailscale connectivity for secure remote access
- Repository tooling pre-installed
- Custom partitioning scripts

## Directory Structure

```
nixos-installer/           # Self-contained installer flake
├── flake.nix              # Installer-specific flake
├── flake.lock             # Pinned dependencies
└── ...

hosts/iso/                 # ISO host configuration in main flake
├── default.nix            # ISO-specific settings
└── (no hardware.nix)      # Uses NixOS installer modules instead
```

## Building the Installer

### Using Just Command (Recommended)

```bash
just iso
```

This builds the installer ISO image and places it in `./result/iso/`.

### Direct Nix Build

```bash
cd nixos-installer
nix build
```

## Testing the Installer

### In QEMU

```bash
just test-iso
```

This launches QEMU with:
- The built ISO mounted
- Appropriate memory allocation
- Network access for testing Tailscale

### Manual QEMU Launch

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -cdrom result/iso/nixos-*.iso \
  -boot d
```

## Writing to USB

```bash
just iso-install
```

This will prompt for the target device and write the ISO.

**⚠️ Warning**: This will erase all data on the target device.

## ISO Host Configuration

The `iso` host in the main flake has special characteristics:

### Minimal Roots

```nix
roots = [ "minimal" ];
```

Only essential modules are included to keep the image small and focused.

### No hardware.nix

Instead of a local hardware configuration, it imports standard NixOS installer modules:

```nix
imports = lib.flatten [
  "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  # ... other installer modules
];
```

### Special Settings

- **Compression**: Uses lower compression level (`zstd -3`) for faster builds
- **Username**: Uses `nixos` instead of `beau`
- **No Tailscale IP**: Network is configured for DHCP

## Relationship to Main Flake

```
┌─────────────────────────────────────────┐
│           Main Flake (flake.nix)        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │    hosts/iso/default.nix        │    │
│  │    - minimal roots only         │    │
│  │    - installer modules          │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │    nixos-installer/             │    │
│  │    - Self-contained flake       │    │
│  │    - Additional installer tools │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

The `nixos-installer/` directory contains a separate flake that can be built independently, while `hosts/iso/` integrates with the main module system.

## Customizing the Installer

### Adding Packages to ISO

Edit `hosts/iso/default.nix` or create modules with `minimal.nix` suffix that should be included.

### Adding SSH Keys

Ensure SSH keys are configured in the minimal security modules so remote installation is possible.

### Network Configuration

The installer uses DHCP by default. For static IP or special network setup, modify the installer's network configuration.

## Installation Workflow

### 1. Boot from ISO

Boot the target machine from the USB drive.

### 2. Connect via SSH (Optional)

If on the same network or via Tailscale:

```bash
ssh nixos@<ip-address>
```

### 3. Partition Disks

Use disko or manual partitioning:

```bash
# With disko (recommended)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /tmp/disk-config.nix

# Or manual
sudo fdisk /dev/nvme0n1
```

### 4. Mount Filesystems

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

### 5. Clone Repository

```bash
sudo git clone <repo-url> /mnt/etc/nixos
```

### 6. Install

```bash
sudo nixos-install --flake /mnt/etc/nixos#<hostname>
```

### 7. Reboot

```bash
sudo reboot
```

## Troubleshooting

### ISO Won't Boot

- Verify secure boot is disabled or keys are enrolled
- Try legacy BIOS mode if UEFI fails
- Check ISO integrity with checksum

### No Network in Installer

- Check physical connection
- Try `sudo systemctl restart NetworkManager`
- For WiFi: `nmcli device wifi connect <SSID> password <password>`

### SSH Connection Refused

- Verify SSH service is running: `systemctl status sshd`
- Check firewall: `sudo iptables -L`
- Ensure correct IP address

## Related Specifications

- [Hosts](./hosts.md) - The iso host configuration
- [Roots](./roots.md) - Why iso only uses minimal root
- [Tooling](./tooling.md) - Just commands for ISO operations
