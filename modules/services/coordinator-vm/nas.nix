{
  config,
  lib,
  pkgs,
  ...
}:
let
  vmName = "agent";
  vmStorageRoot = "/home/agent-vm";
  sharedHostDir = "/home/beau/agent";
  sharedMountTag = "host-agent";
  shareRegistryDir = "/var/lib/agent-share";
  shareRegistryPath = "${shareRegistryDir}/registry.tsv";
  guestVisibleStateDir = "${sharedHostDir}/.pi-hub";
  guestVisibleSharesPath = "${guestVisibleStateDir}/shares.json";
  vmDiskPath = "${vmStorageRoot}/${vmName}.qcow2";
  vmXmlPath = "${vmStorageRoot}/${vmName}.xml";
  installIsoPath = "${vmStorageRoot}/nixos-minimal.iso";
  installIsoUrl = "https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso";
  agentShare = pkgs.writeShellApplication {
    name = "agent-share";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      jq
      util-linux
    ];
    text = ''
      set -euo pipefail

      registry_dir=${lib.escapeShellArg shareRegistryDir}
      registry_path=${lib.escapeShellArg shareRegistryPath}
      shared_root=${lib.escapeShellArg sharedHostDir}
      guest_state_dir=${lib.escapeShellArg guestVisibleStateDir}
      guest_shares_path=${lib.escapeShellArg guestVisibleSharesPath}
      guest_shared_root='/home/beau/host'

      mkdir -p "$registry_dir" "$shared_root" "$guest_state_dir"
      touch "$registry_path"

      usage() {
        cat <<'EOF'
      Usage:
        agent-share add <source-path> <agent-path>
        agent-share remove <agent-path>
        agent-share list
        agent-share restore

      Notes:
        - `add` persists the mapping and bind-mounts it immediately.
        - `agent-path` is relative to the agent home shared root.
        - Run as root, e.g. `sudo agent-share add ~/documents/projects/foo`.
      EOF
      }

      escape_regex() {
        printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\/]/\\\\&/g'
      }

      ensure_target_dir() {
        local target="$1"
        mkdir -p "$target"
      }

      ensure_agent_path() {
        local agent_path="$1"

        if [ -z "$agent_path" ]; then
          echo "error: agent path must not be empty" >&2
          exit 1
        fi

        if [ "$agent_path" = "." ] || [ "$agent_path" = ".." ]; then
          echo "error: invalid agent path: $agent_path" >&2
          exit 1
        fi

        if printf '%s' "$agent_path" | grep -Eq '^/|(^|/)\.\.(/|$)'; then
          echo "error: agent path must be relative to the agent home: $agent_path" >&2
          exit 1
        fi

        if printf '%s' "$agent_path" | grep -Eq '^\.pi-hub(/|$)'; then
          echo "error: agent path uses reserved namespace .pi-hub: $agent_path" >&2
          exit 1
        fi
      }

      sync_guest_manifest() {
        local tmp_json
        local first_entry=1

        tmp_json="$(mktemp)"
        printf '[\n' > "$tmp_json"

        while IFS=$'\t' read -r agent_path source; do
          [ -n "$agent_path" ] || continue
          [ -n "$source" ] || continue

          local host_path="$shared_root/$agent_path"
          local guest_path="$guest_shared_root/$agent_path"
          local entry

          entry="$(
            jq -cn \
              --arg agentPath "$agent_path" \
              --arg sourcePath "$source" \
              --arg hostPath "$host_path" \
              --arg guestPath "$guest_path" \
              '{
                agentPath: $agentPath,
                sourcePath: $sourcePath,
                hostPath: $hostPath,
                guestPath: $guestPath
              }'
          )"

          if [ "$first_entry" -eq 1 ]; then
            printf '  %s' "$entry" >> "$tmp_json"
            first_entry=0
          else
            printf ',\n  %s' "$entry" >> "$tmp_json"
          fi
        done < "$registry_path"

        if [ "$first_entry" -eq 0 ]; then
          printf '\n]\n' >> "$tmp_json"
        else
          printf ']\n' >> "$tmp_json"
        fi

        mv "$tmp_json" "$guest_shares_path"
      }

      mount_share() {
        local source="$1"
        local target="$2"
        ensure_target_dir "$target"

        if mountpoint -q "$target"; then
          local current_source
          current_source="$(findmnt -n -o SOURCE --target "$target" || true)"
          if [ "$current_source" = "$source" ]; then
            return 0
          fi
          echo "error: $target is already mounted from $current_source" >&2
          exit 1
        fi

        mount --bind "$source" "$target"
      }

      remove_registry_entry() {
        local name="$1"
        local escaped_name
        escaped_name="$(escape_regex "$name")"
        local tmp
        tmp="$(mktemp)"
        grep -Ev "^''${escaped_name}	" "$registry_path" > "$tmp" || true
        mv "$tmp" "$registry_path"
      }

      add_share() {
        local source_input="$1"
        local agent_path="$2"
        local source
        source="$(realpath -e "$source_input")"
        local target="$shared_root/$agent_path"

        if [ ! -d "$source" ]; then
          echo "error: source must be an existing directory: $source" >&2
          exit 1
        fi

        ensure_agent_path "$agent_path"

        local existing
        existing="$(awk -F '\t' -v key="$agent_path" '$1 == key { print $2; exit }' "$registry_path")"
        if [ -n "$existing" ] && [ "$existing" != "$source" ]; then
          echo "error: agent path '$agent_path' already points to $existing" >&2
          exit 1
        fi

        mount_share "$source" "$target"

        if [ -z "$existing" ]; then
          printf '%s\t%s\n' "$agent_path" "$source" >> "$registry_path"
        fi

        sync_guest_manifest

        echo "shared $source at $target"
      }

      remove_share() {
        local agent_path="$1"
        local target="$shared_root/$agent_path"

        ensure_agent_path "$agent_path"

        remove_registry_entry "$agent_path"

        if mountpoint -q "$target"; then
          umount "$target"
        fi

        rmdir "$target" 2>/dev/null || true
        sync_guest_manifest
        echo "removed share $agent_path"
      }

      list_shares() {
        if [ ! -s "$registry_path" ]; then
          echo "no agent shares configured"
          return 0
        fi

        while IFS=$'\t' read -r agent_path source; do
          [ -n "$agent_path" ] || continue
          printf '%s\t%s\t%s\n' "$agent_path" "$source" "$shared_root/$agent_path"
        done < "$registry_path"
      }

      restore_shares() {
        while IFS=$'\t' read -r agent_path source; do
          [ -n "$agent_path" ] || continue
          [ -n "$source" ] || continue

          if [ ! -d "$source" ]; then
            echo "warning: skipping missing source for $agent_path: $source" >&2
            continue
          fi

          mount_share "$source" "$shared_root/$agent_path"
        done < "$registry_path"

        sync_guest_manifest
      }

      sync_guest_manifest

      command="''${1:-}"
      case "$command" in
        add)
          [ "$#" -eq 3 ] || { usage; exit 1; }
          add_share "$2" "$3"
          ;;
        remove)
          [ "$#" -eq 2 ] || { usage; exit 1; }
          remove_share "$2"
          ;;
        list)
          [ "$#" -eq 1 ] || { usage; exit 1; }
          list_shares
          ;;
        restore)
          [ "$#" -eq 1 ] || { usage; exit 1; }
          restore_shares
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };
in
{
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  users.users.${config.hostSpec.username}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "agent-vm-console" ''
      exec ${libvirt}/bin/virsh console ${vmName}
    '')
    agentShare
    (writeShellScriptBin "agent-vm-reset" ''
      set -euo pipefail
      ${libvirt}/bin/virsh destroy ${vmName} >/dev/null 2>&1 || true
      ${libvirt}/bin/virsh undefine ${vmName} --nvram >/dev/null 2>&1 || ${libvirt}/bin/virsh undefine ${vmName} >/dev/null 2>&1 || true
      rm -f "${vmDiskPath}"
      rm -f "${vmXmlPath}"
      echo "agent VM reset. Rebuild nas to reprovision."
    '')
    cloud-utils
    libvirt
    qemu
    virt-manager
  ];

  systemd.tmpfiles.rules = [
    "d ${sharedHostDir} 0700 beau users - -"
    "d ${guestVisibleStateDir} 0755 root root - -"
    "d ${shareRegistryDir} 0755 root root - -"
    "f ${shareRegistryPath} 0644 root root - -"
    "d ${vmStorageRoot} 0750 root root - -"
  ];

  systemd.services.agent-share-restore = {
    description = "Restore persistent bind mounts exposed to the agent VM";
    wantedBy = [ "multi-user.target" ];
    before = [ "agent-vm-ensure.service" ];
    after = [ "local-fs.target" ];
    wants = [ "local-fs.target" ];
    path = with pkgs; [
      agentShare
      coreutils
      gawk
      gnugrep
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      ${agentShare}/bin/agent-share restore
    '';
  };

  # Ensures a persistent libvirt VM exists and is started.
  systemd.services.agent-vm-ensure = {
    description = "Ensure libvirt VM '${vmName}' is defined and running";
    after = [
      "agent-share-restore.service"
      "libvirtd.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
      gnugrep
      libvirt
      qemu
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      mkdir -p "${vmStorageRoot}"
      mkdir -p "${sharedHostDir}"

      if ! virsh net-info default >/dev/null 2>&1; then
        echo "libvirt default network is unavailable"
        exit 1
      fi

      if ! virsh net-info default | grep -q "Active:.*yes"; then
        virsh net-start default
      fi
      virsh net-autostart default

      if [ ! -e "${installIsoPath}" ]; then
        curl -fL "${installIsoUrl}" -o "${installIsoPath}"
      fi

      if [ ! -e "${vmDiskPath}" ]; then
        qemu-img create -f qcow2 "${vmDiskPath}" 400G
      fi

      cat > "${vmXmlPath}" <<'EOF'
      <domain type='kvm'>
        <name>agent</name>
        <memory unit='MiB'>5120</memory>
        <currentMemory unit='MiB'>5120</currentMemory>
        <vcpu placement='static'>2</vcpu>
        <cpu mode='host-passthrough' check='none'/>
        <os firmware='efi'>
          <type arch='x86_64' machine='q35'>hvm</type>
          <boot dev='hd'/>
          <boot dev='cdrom'/>
        </os>
        <features>
          <acpi/>
          <apic/>
        </features>
        <memoryBacking>
          <source type='memfd'/>
          <access mode='shared'/>
        </memoryBacking>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>restart</on_crash>
        <devices>
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2' discard='unmap'/>
            <source file='/home/agent-vm/agent.qcow2'/>
            <target dev='vda' bus='virtio'/>
          </disk>
          <disk type='file' device='cdrom'>
            <driver name='qemu' type='raw'/>
            <source file='/home/agent-vm/nixos-minimal.iso'/>
            <target dev='sda' bus='sata'/>
            <readonly/>
          </disk>
          <filesystem type='mount' accessmode='passthrough'>
            <driver type='virtiofs'/>
            <source dir='${sharedHostDir}'/>
            <target dir='${sharedMountTag}'/>
          </filesystem>
          <interface type='network'>
            <source network='default'/>
            <model type='virtio'/>
          </interface>
          <console type='pty'/>
          <serial type='pty'/>
          <graphics type='vnc' autoport='yes' listen='127.0.0.1'/>
          <rng model='virtio'>
            <backend model='random'>/dev/urandom</backend>
          </rng>
        </devices>
      </domain>
      EOF

      if virsh dominfo "${vmName}" >/dev/null 2>&1; then
        echo "Domain '${vmName}' already exists; skipping define"
      else
        virsh define "${vmXmlPath}"
      fi

      virsh autostart "${vmName}"
      if ! virsh domstate "${vmName}" | grep -q running; then
        virsh start "${vmName}"
      fi
    '';
  };
}
