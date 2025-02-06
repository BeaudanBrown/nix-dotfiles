{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.rbw;
in
{
  options.${namespace}.tools.rbw = with types; {
    enable = mkBoolOpt false "Whether or not to enable rbw.";
  };

  config = mkIf cfg.enable
  {
    programs.rbw = {
      enable = true;
      settings = {
        base_url = "https://pw.beaudan.me";
        email = "beaudan.brown@gmail.com";
        pinentry = pkgs.pinentry-rofi;
      };
    };
  };
}
