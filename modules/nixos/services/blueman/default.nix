{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.services.blueman;
in {
  options.${namespace}.services.blueman = {
    enable = mkBoolOpt false "Whether or not to enable blueman.";
  };

  config = mkIf cfg.enable {
    services.blueman.enable = true;
    dotfiles.home.extraOptions = {
      services.blueman-applet.enable = true;
    };
  };
}

