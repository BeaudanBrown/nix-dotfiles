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
    "d ${config.hostSpec.home}/nas 0755 ${config.hostSpec.username} users - -"
    "d ${config.hostSpec.home}/nas/documents 0755 ${config.hostSpec.username} users - -"
    "d ${config.hostSpec.home}/nas/monash 0755 ${config.hostSpec.username} users - -"
    "d ${config.hostSpec.home}/nas/collab 0755 ${config.hostSpec.username} users - -"
  ];

  services.autofs = {
    enable = true;
    autoMaster =
      let
        nasUser = config.hostSpecs.nas.users |> builtins.head;
        nasHome = "/home/${nasUser.username}";
        cifsConf = pkgs.writeText "auto.cifs" ''
          /mnt/monash-shared -fstype=cifs,credentials=${config.sops.secrets.smbcredentials.path},uid=1000,gid=1000,iocharset=utf8,sec=ntlmssp,_netdev,nounix,cache=strict,vers=3.0,actimeo=60 ://ad.monash.edu/shared/Epi-Dementia
        '';
        agentConf = pkgs.writeText "auto.agent-nfs" ''
          ${config.hostSpec.home}/nas/agent -fstype=nfs4,rw,hard,noatime,proto=tcp,port=2049,_netdev ${config.hostSpecs.nas.tailIP}:/pool1/agent
        '';
        sharedConf = pkgs.writeText "auto.shared-nfs" ''
          ${config.hostSpec.home}/nas/documents -fstype=nfs4,rw,hard,noatime,proto=tcp,port=2049,_netdev ${config.hostSpecs.nas.tailIP}:${nasHome}/documents
          ${config.hostSpec.home}/nas/monash -fstype=nfs4,rw,hard,noatime,proto=tcp,port=2049,_netdev ${config.hostSpecs.nas.tailIP}:${nasHome}/monash
          ${config.hostSpec.home}/nas/collab -fstype=nfs4,rw,hard,noatime,proto=tcp,port=2049,_netdev ${config.hostSpecs.nas.tailIP}:${nasHome}/collab
        '';
      in
      ''
        /- file:${cifsConf} --timeout=300
        /- file:${agentConf} --timeout=60
        /- file:${sharedConf} --timeout=60
      '';
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
  ];
}
