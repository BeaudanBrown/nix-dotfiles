{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Create all users defined in hostSpec
  users.users = lib.listToAttrs (
    map (
      user:
      lib.nameValuePair user.username {
        isNormalUser = true;
        home = user.home;
        extraGroups = [ "wheel" ] ++ user.extraGroups;
        group = "users";
        shell = pkgs.zsh;
        uid = user.uid;
        hashedPassword = "$y$j9T$rxvMdBfBYR6YMFmQOTEl90$qAOeCeZFDuv8v6eFiqtjZGsL6yuB2e5mhi5dZt3Ts37";
      }
    ) config.hostSpec.users
  );

  # Create .config directory for all users
  systemd.tmpfiles.rules = map (
    user: "d ${user.home}/.config 0755 ${user.username} users - -"
  ) config.hostSpec.users;

  # Root inherits password from primary user
  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.primaryUser.username}) hashedPassword;
    initialHashedPassword = lib.mkForce null;
  };

  # Shared XDG user directories configuration for all users
  # Note: Home Manager will automatically use each user's own home directory
  hm.all.xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      # These paths are relative to each user's home
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      desktop = null;
      pictures = null;
      music = null;
      publicShare = null;
      templates = null;
      videos = null;
    };
  };
}
