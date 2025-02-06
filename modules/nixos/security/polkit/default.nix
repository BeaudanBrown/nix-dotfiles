{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.sudo;
in
{
  options.${namespace}.security.sudo = {
    enable = mkBoolOpt false "Whether or not to configure sudo.";
  };

  config = mkIf cfg.enable {
    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command =  "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
          {
            command =  "/run/current-system/sw/bin/reboot";
            options = [ "NOPASSWD" ];
          }
          {
            command =  "/run/current-system/sw/bin/shutdown";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
