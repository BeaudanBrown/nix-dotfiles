{ lib, ... }:
{
  # Enable cross-building for Raspberry Pi targets on the NAS
  # This registers QEMU binfmt for the target systems and wires Nix accordingly.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  # Let the builder use more jobs by default; can be overridden per-host
  nix.settings.max-jobs = lib.mkDefault 8;
}
