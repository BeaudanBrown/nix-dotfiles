{
  pkgs,
  config,
  lib,
  ...
}:
{
  sops = {
    secrets = {
      smbcredentials = {
        sopsFile = lib.custom.sopsFileForModule __curPos.file;
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
          /s -fstype=cifs,credentials=${config.sops.secrets.smbcredentials.path},uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,nounix,cache=strict,vers=3.0,actimeo=60 ://ad.monash.edu/shared/Epi-Dementia
        '';
      in
      ''
        /- file:${cifsConf} --timeout=300
      '';
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];
}
