{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.nh;
in {
  options.${namespace}.cli.nh = {
    enable = mkBoolOpt false "Whether to enable nh configuration.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = [ pkgs.nh ];
    };
  };
}
