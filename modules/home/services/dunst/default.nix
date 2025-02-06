{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.dunst;
in
{
  options.${namespace}.services.dunst = with types; {
    enable = mkBoolOpt false "Whether or not to enable dunst.";
  };

  config = mkIf cfg.enable {
    services.dunst = {
      enable = true;
    };
  };
}
