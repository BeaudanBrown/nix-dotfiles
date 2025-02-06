{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.kitty;
in
{
  options.${namespace}.apps.kitty = with types; {
    enable = mkBoolOpt false "Whether or not to enable kitty.";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = {
      TERMINAL = "kitty";
    };
    dotfiles.home.extraOptions = {
      dotfiles.apps.kitty = enabled;
    };
  };
}
