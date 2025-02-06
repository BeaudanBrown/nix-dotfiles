{ config
, lib
, namespace
, ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.adb;
in
{
  options.${namespace}.tools.adb = with types; {
    enable = mkBoolOpt true "Whether or not to manage adb.";
  };

  config = mkIf cfg.enable {
    programs.adb.enable = true;
    dotfiles.user.extraGroups = [ "adbusers" ];
  };
}
