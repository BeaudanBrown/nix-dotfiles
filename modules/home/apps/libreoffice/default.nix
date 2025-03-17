{
  config,
  lib,
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
    enable = mkBoolOpt false "Whether or not to enable libreoffice configuration.";
  };

  config = mkIf cfg.enable {
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
}
