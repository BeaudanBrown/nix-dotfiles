{
  config,
  pkgs,
  lib,
  ...
}:
{
  users.users.${config.hostSpec.username} = {
    isNormalUser = true;
    home = "/home/${config.hostSpec.username}";
    extraGroups = [ "wheel" ];
    group = "users";
    shell = pkgs.zsh;
    uid = 1000;
    hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
  };

  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
    initialHashedPassword = lib.mkForce null;
  };

  home-manager.users.${config.hostSpec.username}.xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "${config.home-manager.users.${config.hostSpec.username}.home.homeDirectory}/documents";
      download = "${config.home-manager.users.${config.hostSpec.username}.home.homeDirectory}/downloads";
      desktop = null;
      pictures = null;
      music = null;
      publicShare = null;
      templates = null;
      videos = null;
    };
  };
}
