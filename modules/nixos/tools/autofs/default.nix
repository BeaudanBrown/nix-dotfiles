{ config
, pkgs
, lib
, namespace
, ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tools.autofs;
in
{
  options.${namespace}.tools.autofs = with types; {
    enable = mkBoolOpt true "Whether or not to manage autofs.";
  };

  config = mkIf cfg.enable {
    services.autofs = {
      enable = true;
      autoMaster = let
        cifsConf = pkgs.writeText "auto.cifs" ''
        /s -fstype=cifs,credentials=/home/beau/.config/smbcredentials,uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,soft,cache=none ://ad.monash.edu/shared
        '';
      in ''
      /- file:${cifsConf}
      '';
    };

    environment.systemPackages = with pkgs; [
      nfs-utils
    ];
  };
}
