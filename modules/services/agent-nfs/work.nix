{ config, pkgs, ... }:
let
  agentMount = "${config.hostSpec.home}/nas/agent";
in
{
  systemd.tmpfiles.rules = [
    "d ${agentMount} 0755 ${config.hostSpec.username} users - -"
  ];

  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
}
