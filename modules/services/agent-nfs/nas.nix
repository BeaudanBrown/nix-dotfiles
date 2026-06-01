{ config, pkgs, ... }:
let
  agentRoot = "/pool1/agent";
  agentMount = "${config.hostSpec.home}/agent";
  tailnetCidr = "100.64.0.0/10";
in
{
  systemd.tmpfiles.rules = [
    "d ${agentRoot} 0770 ${config.hostSpec.username} users - -"
    "d ${agentMount} 0755 ${config.hostSpec.username} users - -"
  ];

  systemd.services.agent-home-bind-mount = {
    description = "Bind mount NAS agent storage into the primary user's home";
    wantedBy = [ "multi-user.target" ];
    before = [ "agent-share-restore.service" ];
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [ "local-fs.target" ];
    path = with pkgs; [
      coreutils
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      mkdir -p ${agentRoot} ${agentMount}

      if mountpoint -q ${agentMount}; then
        current_source="$(findmnt -n -o SOURCE --target ${agentMount} || true)"
        if [ "$current_source" = ${agentRoot} ]; then
          exit 0
        fi

        echo "${agentMount} is already mounted from $current_source; refusing to replace it" >&2
        exit 1
      fi

      mount --bind ${agentRoot} ${agentMount}
    '';
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      ${agentRoot} ${tailnetCidr}(rw,sync,no_subtree_check,root_squash,crossmnt)
    '';
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];
}
