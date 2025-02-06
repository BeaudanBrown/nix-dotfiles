{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.stylix;
in
{
  options.${namespace}.system.stylix = with types; {
    enable = mkBoolOpt false "Whether or not to manage stylix.";
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      image = ./bg.png;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

      targets = {
        grub.useImage = true;
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
    dotfiles.home.extraOptions.stylix.enable = true;
  };
}
