{
  lib,
  inputs,
  pkgs,
  config,
  ...
}:
{
  imports =
    [
      ./hardware.nix

      inputs.sops-nix.nixosModules.sops
      inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ (map lib.custom.relativeToRoot [
      "modules/nixos/common"
      "modules/nixos/pi4"
    ]);

  hostSpec = {
    username = "beau";
    hostName = "pi4";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8023;
  };

  home-manager = {
    backupFileExtension = "backup";
    users.${config.hostSpec.username}.imports = (
      map lib.custom.relativeToRoot [
        "modules/home/common"
        "modules/home/pi4"
      ]
    );
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
    ];
    loader = {
      # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
      grub.enable = false;
      # Enables the generation of /boot/extlinux/extlinux.conf
      generic-extlinux-compatible.enable = true;
    };
  };

  nix.settings.cores = 4;
  system.stateVersion = "25.05";
}
