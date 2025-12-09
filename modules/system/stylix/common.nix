{ pkgs, ... }:
{
  stylix = {
    enable = true;
    image = ./bg.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

    targets = {
      grub.enable = false;
      nixvim.enable = false;
      gnome.enable = false;
    };

    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sizes = {
        applications = 14;
        terminal = 12;
        popups = 18;
      };
    };
    cursor = {
      package = pkgs.quintom-cursor-theme;
      name = "Quintom_Ink";
      size = 24;
    };
  };

  hm.stylix.enable = true;
}
