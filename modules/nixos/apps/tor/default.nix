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
  cfg = config.${namespace}.apps.tor;
in
{
  options.${namespace}.apps.tor = with types; {
    enable = mkBoolOpt false "Whether or not to enable tor.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.tor-browser ];
    };
  };
}
