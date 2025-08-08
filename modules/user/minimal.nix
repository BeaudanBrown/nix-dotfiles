{
  config,
  pkgs,
  lib,
  ...
}:
{
  users.users.${config.hostSpec.username} = {
    isNormalUser = true;
    home = "${config.hostSpec.home}";
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

  hm.xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "${config.hostSpec.home}/documents";
      download = "${config.hostSpec.username}/downloads";
      desktop = null;
      pictures = null;
      music = null;
      publicShare = null;
      templates = null;
      videos = null;
    };
  };
}
