{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.services.printing;
in {
  options.${namespace}.services.printing = {
    enable = mkBoolOpt false "Whether or not to enable printing.";
  };

  config = mkIf cfg.enable { services.printing.enable = true; };
}
