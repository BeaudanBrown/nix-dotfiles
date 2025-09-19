{ pkgs, config, ... }:
{
  sops = {
    # Which secrets to use, get stored by default in /run/secrets/<name>
    secrets = {
      smbcredentials = {
        # Other username is bcam0018
        path = "${config.hostSpec.home}/.config/smbcredentials";
        owner = config.hostSpec.username;
        inherit (config.users.users.${config.hostSpec.username}) group;
        mode = "0600";
      };
    };
  };

  services.autofs = {
    enable = true;
    autoMaster =
      let
        cifsConf = pkgs.writeText "auto.cifs" ''
          /s -fstype=cifs,credentials=${config.sops.secrets.smbcredentials.path},uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,soft,cache=none,vers=3.0 ://ad.monash.edu/shared
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
