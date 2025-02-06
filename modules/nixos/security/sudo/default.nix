{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.polkit;
in
{
  options.${namespace}.security.polkit = {
    enable = mkBoolOpt false "Whether or not to enable polkit.";
  };

  config = mkIf cfg.enable {
    security = {
      polkit.enable = true;
    };
  };
}
