{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtiofs"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
