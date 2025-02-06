{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.misc;
in
{
  options.${namespace}.apps.misc = with types; {
    enable = mkBoolOpt false "Whether or not to enable misc apps.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      audacity
      calibre
      caprine
      discord
      gparted
      libreoffice
      nautilus
      qbittorrent
      signal-desktop
      slack
      spotify
      sxiv
      tor-browser
      vlc
      zoom-us
    ];
    programs.autojump.enable = true;
    programs.kdeconnect.enable = true;
  };
}
