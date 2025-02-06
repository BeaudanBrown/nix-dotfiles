{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.services.udisks2;
in {
  options.${namespace}.services.udisks2 = {
    enable = mkBoolOpt false "Whether or not to enable udisks2.";
  };

  config = mkIf cfg.enable {
    services.udisks2 = {
      enable = true;
      mountOnMedia = true;
    };
 };
}
