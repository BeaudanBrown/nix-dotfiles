{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.networking;
in
{
  options.${namespace}.hardware.networking = with types; {
    enable = mkBoolOpt false "Whether or not to enable networking support";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      networkmanager-openconnect
      networkmanagerapplet
      openconnect
    ];
    dotfiles.user.extraGroups = [ "networkmanager" ];
    networking = {
      nameservers = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      networkmanager = {
        enable = true;
        plugins = [
          pkgs.networkmanager-openconnect
        ];
      };
    };
  };
}

