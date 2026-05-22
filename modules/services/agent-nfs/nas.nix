{ config, ... }:
let
  agentRoot = "/pool1/agent";
  tailnetCidr = "100.64.0.0/10";
in
{
  systemd.tmpfiles.rules = [
    "d ${agentRoot} 0770 ${config.hostSpec.username} users - -"
  ];

  services.nfs.server = {
    enable = true;
    exports = ''
      ${agentRoot} ${tailnetCidr}(rw,sync,no_subtree_check,root_squash)
    '';
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];
}
