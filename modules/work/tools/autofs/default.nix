{ pkgs, config, ... }:
{
  services.autofs = {
    enable = true;
    autoMaster =
      let
        cifsConf = pkgs.writeText "auto.cifs" ''
          /s -fstype=cifs,credentials=/home/${config.hostSpec.username}/.config/smbcredentials,uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,soft,cache=none,vers=3.0 ://ad.monash.edu/shared
        '';
      in
      ''
        /- file:${cifsConf}
      '';
  };

  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
}
