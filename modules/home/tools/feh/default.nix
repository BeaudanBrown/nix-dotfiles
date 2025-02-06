{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.feh;
in
{
  options.${namespace}.tools.feh = with types; {
    enable = mkBoolOpt false "Whether or not to enable feh.";
  };

  config = mkIf cfg.enable {
    programs.feh = {
      enable = true;
      keybindings = {
        prev_img = [
          "h"
          "Left"
        ];
        next_img = [
          "l"
          "Right"
        ];
        zoom_in = "K";
        zoom_out = "J";
      };
    };
  };
}
