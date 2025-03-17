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
  cfg = config.${namespace}.apps.libreoffice;
in
{
  options.${namespace}.apps.libreoffice = with types; {
    enable = mkBoolOpt false "Whether or not to enable libreoffice.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libreoffice
    ];
    snowfallorg.users.${config.${namespace}.user.name}.home.config = {
      xdg = {
        mimeApps = {
          enable = true;
          # to see available > ls /run/current-system/sw/share/applications/
          defaultApplications = {
            "application/msword" = [ "writer.desktop" ];
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "writer.desktop" ];
          };
        };
      };
    };
  };
}
