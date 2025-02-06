{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.desktop.addons.playerctld;

  inherit (lib) mkIf mkEnableOption;
in
{
  options.${namespace}.desktop.addons.playerctld = {
    enable = mkEnableOption "playerctld";
  };

  config = mkIf cfg.enable {
    services.playerctld.enable = true;
};
}

