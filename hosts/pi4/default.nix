{
lib,
inputs,
pkgs,
config,
host,
...
}:
let
  roots =
    [
      "common"
    ];
in
  {
  imports =
    [
      ./hardware.nix

      inputs.sops-nix.nixosModules.sops
      inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
    ] ++ (lib.custom.importAll {
      inherit host roots;
      spec = config.hostSpec;
    });

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

  system.stateVersion = "25.05";
}
