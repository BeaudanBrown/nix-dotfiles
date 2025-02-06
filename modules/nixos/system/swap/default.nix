{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.swap;
in
{
  options.${namespace}.system.swap = with types; {
    enable = mkBoolOpt false "Whether or not to enable swap management.";
  };

  config = mkIf cfg.enable {
    swapDevices = [
      {
        device = "/var/lib/swapfile";
        size = 16*1024;
      }
    ];
  };
}
