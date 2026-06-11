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
    unitConfig.RequiresMountsFor = agentRoot;
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

      root_identity="$(stat -Lc '%d:%i' ${agentRoot})"

      if mountpoint -q ${agentMount}; then
        mount_identity="$(stat -Lc '%d:%i' ${agentMount})"
        if [ "$mount_identity" = "$root_identity" ]; then
          exit 0
        fi

        current_source="$(findmnt -n -o SOURCE --target ${agentMount} || true)"
        echo "${agentMount} is already mounted from $current_source and does not match ${agentRoot}; refusing to replace it" >&2
        exit 1
      fi

      mount --bind ${agentRoot} ${agentMount}

      mount_identity="$(stat -Lc '%d:%i' ${agentMount})"
      if [ "$mount_identity" != "$root_identity" ]; then
        current_source="$(findmnt -n -o SOURCE --target ${agentMount} || true)"
        echo "${agentMount} mounted from $current_source but does not match ${agentRoot}" >&2
        exit 1
      fi
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
