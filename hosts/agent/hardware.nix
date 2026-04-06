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

  # Persistent libvirt disk layout for the agent VM.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [
    {
      device = "/swapfile";
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
