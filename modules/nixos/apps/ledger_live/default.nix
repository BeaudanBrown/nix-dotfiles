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
  cfg = config.${namespace}.apps.ledger_live;
in
{
  options.${namespace}.apps.ledger_live = with types; {
    enable = mkBoolOpt false "Whether or not to enable ledger live.";
  };

  config = mkIf cfg.enable {
    hardware.ledger.enable = true;
    environment.systemPackages = with pkgs; [
      ledger-live-desktop
    ];
  };
}
