{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;
  home = {
    username = "beau";
    homeDirectory = "/home/beau";
    stateVersion = "23.05";
    pointerCursor = {
      package = pkgs.quintom-cursor-theme;
      name = "Quintom_Ink";
      size = 24;
      gtk.enable = true;
    };
  };

  imports = [
    # ./desktops/hyprland
    ./modules/home/bspwm
  ];

  # xdg.configFile.oh-my-posh = {
  #   enable = true;
  # };
}
