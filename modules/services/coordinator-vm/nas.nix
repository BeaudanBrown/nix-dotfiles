{
  config,
  pkgs,
  ...
}:
let
  vmName = "agent";
  vmStorageRoot = "/home/agent-vm";
  sharedHostDir = "/home/beau/agent";
  vmDiskPath = "${vmStorageRoot}/${vmName}.qcow2";
  vmXmlPath = "${vmStorageRoot}/${vmName}.xml";
  installIsoPath = "${vmStorageRoot}/nixos-minimal.iso";
  installIsoUrl = "https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso";
in
{
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  users.users.${config.hostSpec.username}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "agent-vm-console" ''
      exec ${libvirt}/bin/virsh console ${vmName}
    '')
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
    "d ${vmStorageRoot} 0750 root root - -"
  ];

  # Ensures a persistent libvirt VM exists and is started.
  systemd.services.agent-vm-ensure = {
    description = "Ensure libvirt VM '${vmName}' is defined and running";
    after = [
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
        <os>
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
            <source dir='/home/beau/agent'/>
            <target dir='host-agent'/>
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
