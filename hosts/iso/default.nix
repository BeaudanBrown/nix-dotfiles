{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = lib.flatten [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    inputs.home-manager.nixosModules.home-manager
    (lib.custom.importAll {
      host = "iso";
      roots = [ "minimal" ];
      spec = config.hostSpec;
    })
  ];

  environment.systemPackages = with pkgs; [
    vim
  ];

  hostSpec = {
    hostName = "iso";
    username = "beau";
    email = "beaudan.brown@gmail.com";
    userFullName = "Beaudan Brown";
    sshPort = 22;
  };

  # The default compression-level is (6) and takes too long on some machines (>30m). 3 takes <2m
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.qemuGuest.enable = true;

  # root's ssh key are mainly used for remote deployment
  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
    openssh.authorizedKeys.keys =
      config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
  };

  users.users.${config.hostSpec.username} = {
    hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
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
