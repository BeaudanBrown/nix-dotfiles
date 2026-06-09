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
  # Keep the phone on the known-good boot argument shape. The common desktop
  # boot module adds PC-oriented parameters that are unnecessary here, and the
  # working generation used this exact console/initrd logging set.
  boot.kernelParams = lib.mkForce [
    "console=ttyGS0,115200"
    "clk_ignore_unused"
    "pd_ignore_unused"
    "arm64.nopauth"
    "console=ttyMSM0,115200n8"
    "console=tty0"
    "rd.systemd.default_standard_output=kmsg+console"
    "rd.systemd.default_standard_error=kmsg+console"
    "rd.systemd.journald.forward_to_console=1"
    "rd.systemd.log_target=console"
    "rd.systemd.journald.forward_to_console=1"
    "root=fstab"
    "loglevel=8"
    "lsm=landlock,yama,bpf"
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
