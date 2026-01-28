{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  imports =
    let
      allHostsData = import ../../modules/host-spec/all-hosts.nix;
      roots = allHostsData.hostSpecs.iso.roots;
    in
    lib.flatten [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      (lib.custom.importAll {
        host = "iso";
        inherit roots;
      })
    ];

  environment.systemPackages = with pkgs; [
    vim
  ];

  thisHost = "iso";

  # The default compression-level is (6) and takes too long on some machines (>30m). 3 takes <2m
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.qemuGuest.enable = true;

  # root's ssh key are mainly used for remote deployment
  users.extraUsers.root = {
    openssh.authorizedKeys.keys =
      config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
  };

  boot = {
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "vfat"
    ];
  };

  systemd = {
    services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
    # gnome power settings to not turn off screen
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
