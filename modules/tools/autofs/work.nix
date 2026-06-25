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

  systemd.tmpfiles.rules = [
    "d /mnt 0755 root root - -"
    "d /mnt/monash-shared 0755 root root - -"
    "L+ ${config.hostSpec.home}/s - - - - /mnt/monash-shared"
  ];

  services.autofs = {
    enable = true;
    autoMaster =
      let
        cifsConf = pkgs.writeText "auto.cifs" ''
          /mnt/monash-shared -fstype=cifs,credentials=${config.sops.secrets.smbcredentials.path},uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,nounix,cache=strict,vers=3.0,actimeo=60 ://ad.monash.edu/shared/Epi-Dementia
        '';
        agentConf = pkgs.writeText "auto.agent-nfs" ''
          ${config.hostSpec.home}/agent -fstype=nfs4,rw,hard,noatime,proto=tcp,port=2049,_netdev ${config.hostSpecs.nas.tailIP}:/pool1/agent
        '';
      in
      ''
        /- file:${cifsConf} --timeout=300
        /- file:${agentConf} --timeout=60
      '';
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];
}
