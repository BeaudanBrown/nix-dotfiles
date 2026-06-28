{ lib, ... }:
{
  # Enable cross-building for Raspberry Pi targets on the NAS
  # This registers QEMU binfmt for the target systems and wires Nix accordingly.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  # Let the builder use more jobs by default; can be overridden per-host
  nix.settings.max-jobs = lib.mkDefault 8;

  nixpkgs.config.permittedInsecurePackages = lib.mkForce [
    # Jitsi Meet currently depends on deprecated libolm.
    "jitsi-meet-1.0.8792"

    # Required by mautrix bridge packages while upstream Matrix clients/bridges
    # continue migrating away from deprecated libolm.
    "olm-3.2.16"
  ];
}
