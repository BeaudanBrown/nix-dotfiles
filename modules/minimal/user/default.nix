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
}
