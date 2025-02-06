{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland;
in
{
  options.${namespace}.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to enable hyprland.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libnotify
      (import ./scripts/hyprland_show_app.nix { inherit pkgs; })
    ];
    programs.light.enable = true;
    dotfiles.user.extraGroups = [ "video" ];

    programs.hyprland = enabled;
    services.xserver = {
      enable = true;
      autoRepeatDelay = 175;
      autoRepeatInterval = 50;
      displayManager = {
        gdm = {
          enable = true;
          wayland = true;
        };
      };
      xkb = {
        layout = "au";
        variant = "";
        options = "caps:escape";
      };
    };

    dotfiles = {
      desktop.addons = {
        playerctld = enabled;
        clipboard = enabled;
      };

      nix.extra-substituters = {
        "https://hyprland.cachix.org".key = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
      };
    };
  };
}
