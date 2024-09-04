{ configLib, pkgs, ... }:
{
  imports = (configLib.scanPaths ./.) ++
  (map configLib.relativeToRoot [
    "home/common/core"
  ]);

  # TODO: Gnome stuff
  # dconf.settings = {
  #   "org/gnome/shell" = {
  #     disable-user-extensions = false;
  #     enabled-extensions = [
  #       "bluetooth-quick-connect@jarosze.gmail.com"
  #       "dash-to-panel@jderose9.github.com"
  #     ];
  #   };
  # };
  # home.packages = with pkgs; [
  #   gnomeExtensions.bluetooth-quick-connect
  #   gnomeExtensions.dash-to-panel
  # ];

  home.packages = with pkgs; [
    direnv
  ];
}


