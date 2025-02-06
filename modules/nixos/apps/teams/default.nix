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
  cfg = config.${namespace}.apps.teams;
in
{
  options.${namespace}.apps.teams = with types; {
    enable = mkBoolOpt false "Whether or not to enable teams.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.teams-for-linux ];
    };
  };
}
