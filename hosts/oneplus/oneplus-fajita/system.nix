{ lib, pkgs, config, ... }:
{
  imports = [
    ./hardware/qualcomm-services.nix
    ./hardware/sdm845.nix
    ./image/repart.nix
    ./networking/ssh.nix
    ./networking/wireless.nix
    ./ui/phosh.nix
  ];
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
  };
  boot.kernelParams = [ "console=ttyGS0,115200" ];
  boot.kernelPatches = [
    {
      name = "usb-otg-serial";
      patch = null;
      structuredExtraConfig = {
        USB_G_SERIAL = lib.mkForce lib.kernel.yes;
        U_SERIAL_CONSOLE = lib.mkForce lib.kernel.yes;
        USB_U_SERIAL = lib.mkForce lib.kernel.yes;
      };
    }
  ];
  security.polkit.enable = true;
  services.dbus.packages = [
    config.systemd.package
  ];
  networking.hostName = "oneplus";
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    trusted-public-keys = [
      "cache.bepis.lol:RICGW/iQ761PR6QiMUwbOLcvKird8EHoDd/ylnDOGJY="
    ];
    substituters = [
      "https://cache.bepis.lol"
    ];
    builders-use-substitutes = true;
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [
      "--login-server=https://hs.bepis.lol"
      "--accept-dns=true"
      "--accept-routes=true"
    ];
  };

  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
  };

  system.stateVersion = "25.11";
}
