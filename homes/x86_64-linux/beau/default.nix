{
  lib,
  pkgs,
  config,
  osConfig ? { },
  format ? "unknown",
  namespace,
  ...
}:
with lib.${namespace};
{
  dotfiles = {
    services = {
      dunst = enabled;
    };
    tools = {
      direnv = enabled;
      feh = enabled;
      fzf = enabled;
      rofi = enabled;
      rbw = enabled;
    };
    cli = {
      zsh = enabled;
    };
    apps = {
      zathura = enabled;
    };
    desktop = {
      hyprland = enabled;
    };
  };
}
