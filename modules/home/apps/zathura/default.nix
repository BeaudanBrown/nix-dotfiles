{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.zathura;
in
{
  options.${namespace}.apps.zathura = with types; {
    enable = mkBoolOpt false "Whether or not to enable zathura.";
  };

  config = mkIf cfg.enable {
    xdg = {
      mimeApps = {
        enable = true;
        # to see available > ls /run/current-system/sw/share/applications/
        defaultApplications = {
          "application/pdf" = [
            "org.pwmt.zathura.desktop"
          ];
        };
      };
    };
    programs.zathura = {
      enable = true;
      mappings = {
        "J" = "zoom out";
        "K" = "zoom in";
      };
      options = {
        selection-clipboard = "clipboard";
      };
    };
  };
}
