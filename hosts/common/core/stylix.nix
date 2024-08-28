{ pkgs, configLib, ... }:
{
  stylix = {
    enable = true;
    image = configLib.relativeToRoot "bg.png";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

    targets = {
      grub.useImage = true;
      nixvim.enable = false;
      gnome.enable = false;
    };

    polarity = "dark";

    fonts = {
      monospace = {
        package = pkgs.nerdfonts;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sizes = {
        applications = 14;
        terminal = 12;
      };
    };
    cursor = {
      package = pkgs.quintom-cursor-theme;
      name = "Quintom_Ink";
      size = 24;
    };
  };
}
