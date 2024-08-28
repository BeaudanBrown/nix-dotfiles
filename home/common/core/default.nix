{ config, configLib, ... }:
{
  imports = (configLib.scanPaths ./.);

  programs.home-manager.enable = true;
  home = {
    username = "beau";
    homeDirectory = "/home/beau";
    stateVersion = "23.05";
  };

  xdg = {
    mimeApps = {
      enable = true;
      # to see available desktop files > ls /run/current-system/sw/share/applications/
      defaultApplications = {
        "application/pdf" = [
          "org.pwmt.zathura.desktop"
          "org.kde.okular.desktop"
        ];
        "text/plain" = ["nvim.desktop"];
      };
    };
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

  services.blueman-applet.enable = true;
}
