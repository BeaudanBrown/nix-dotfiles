# Placeholder hardware profile for the Linode host.
# Replace this with nixos-anywhere generated hardware when bootstrapping.
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "ahci"
    "sd_mod"
    "sr_mod"
    "virtio_pci"
    "virtio_scsi"
  ];
  boot.kernelModules = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
