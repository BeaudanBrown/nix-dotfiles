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
  cfg = config.${namespace}.apps.brave;
in
{
  options.${namespace}.apps.brave = with types; {
    enable = mkBoolOpt false "Whether or not to enable brave.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.brave ];
      variables.BROWSER = "brave";
    };
    dotfiles.home.extraOptions = {
      xdg = {
        mimeApps = {
          enable = true;
          # to see available > ls /run/current-system/sw/share/applications/
          defaultApplications = {
            "x-scheme-handler/http" = [ "brave-browser.desktop" ];
            "x-scheme-handler/https" = [ "brave-browser.desktop" ];
          };
        };
      };
    };
  };
}
