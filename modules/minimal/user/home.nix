{
  config,
  lib,
  osConfig,
  ...
}:
{
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "${config.home.homeDirectory}/documents";
      download = "${config.home.homeDirectory}/downloads";
      desktop = null;
      pictures = null;
      music = null;
      publicShare = null;
      templates = null;
      videos = null;
    };
  };

  # TODO: Put this somewhere better
  home.stateVersion = lib.mkDefault (osConfig.system.stateVersion or "23.05");
}
