{
  lib,
  config,
  ...
}:
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
      configurationLimit = lib.mkForce 10;
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
  services.dbus = {
    # Avoid a live dbus -> dbus-broker implementation change on the phone.
    # That change is blocked by NixOS switch inhibitors and should only happen
    # through `nixos-rebuild boot` + reboot if we decide to adopt it later.
    implementation = "dbus";
    packages = [
      config.systemd.package
    ];
  };
  networking.hostName = "oneplus";
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
      "fetch-closure"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
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
