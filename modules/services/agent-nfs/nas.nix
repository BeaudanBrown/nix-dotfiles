{ config, pkgs, ... }:
let
  agentRoot = "/pool1/agent";
  agentMount = "${config.hostSpec.home}/agent";
  sharedRoot = "/pool1/shared";
  sharedFolderNames = [
    "documents"
    "monash"
    "collab"
  ];
  sharedRoots = sharedFolderNames |> map (name: "${sharedRoot}/${name}");
  sharedHomeMounts = [
    {
      source = sharedRoot;
      target = "${config.hostSpec.home}/sync";
    }
  ]
  ++ (
    sharedFolderNames
    |> map (name: {
      source = "${sharedRoot}/${name}";
      target = "${config.hostSpec.home}/${name}";
    })
  );
  tailnetCidr = "100.64.0.0/10";
  nfsExports =
    [ agentRoot ] ++ sharedRoots
    |> map (path: "${path} ${tailnetCidr}(rw,sync,no_subtree_check,root_squash,crossmnt)")
    |> builtins.concatStringsSep "\n";
in
{
  systemd.tmpfiles.rules = [
    "d ${agentRoot} 0770 ${config.hostSpec.username} users - -"
    "d ${agentMount} 0755 ${config.hostSpec.username} users - -"
    "d ${sharedRoot} 0770 ${config.hostSpec.username} users - -"
  ]
  ++ (sharedRoots |> map (path: "d ${path} 0770 ${config.hostSpec.username} users - -"))
  ++ (
    sharedHomeMounts |> map (mount: "d ${mount.target} 0755 ${config.hostSpec.username} users - -")
  );

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

  systemd.services.shared-home-bind-mount = {
    description = "Bind mount shared NAS storage into the primary user's home";
    wantedBy = [ "multi-user.target" ];
    requiredBy = [ "syncthing.service" ];
    before = [ "syncthing.service" ];
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = sharedRoot;
    path = with pkgs; [
      coreutils
      findutils
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      bind_shared_path() {
        source_path="$1"
        target_path="$2"

        mkdir -p "$source_path" "$target_path"
        source_identity="$(stat -Lc '%d:%i' "$source_path")"

        if mountpoint -q "$target_path"; then
          target_identity="$(stat -Lc '%d:%i' "$target_path")"
          if [ "$target_identity" = "$source_identity" ]; then
            return
          fi

          current_source="$(findmnt -n -o SOURCE --target "$target_path" || true)"
          echo "$target_path is already mounted from $current_source and does not match $source_path; refusing to replace it" >&2
          exit 1
        fi

        if [ -n "$(find "$target_path" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
          echo "$target_path is not empty; move its current contents before enabling the shared bind mounts" >&2
          exit 1
        fi

        mount --bind "$source_path" "$target_path"

        target_identity="$(stat -Lc '%d:%i' "$target_path")"
        if [ "$target_identity" != "$source_identity" ]; then
          current_source="$(findmnt -n -o SOURCE --target "$target_path" || true)"
          echo "$target_path mounted from $current_source but does not match $source_path" >&2
          exit 1
        fi
      }

      bind_shared_path ${sharedRoot} ${config.hostSpec.home}/sync
      bind_shared_path ${sharedRoot}/documents ${config.hostSpec.home}/documents
      bind_shared_path ${sharedRoot}/monash ${config.hostSpec.home}/monash
      bind_shared_path ${sharedRoot}/collab ${config.hostSpec.home}/collab
    '';
  };

  services.nfs.server = {
    enable = true;
    exports = "${nfsExports}\n";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];
}
