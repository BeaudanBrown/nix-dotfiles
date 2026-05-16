{
  config,
  pkgs,
  ...
}:
let
  vmName = "lachy-vm";
  vmStorageRoot = "/home/lachy-vm";
  vmDiskPath = "${vmStorageRoot}/${vmName}.qcow2";
  vmXmlPath = "${vmStorageRoot}/${vmName}.xml";
  networkXmlPath = "${vmStorageRoot}/${vmName}-network.xml";
  installIsoPath = "${vmStorageRoot}/nixos-minimal.iso";
  installIsoUrl = "https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso";

  networkName = "lachy-vm";
  vmMac = "52:54:00:80:00:02";
  vmIp = "10.80.0.2";
  hostIp = "10.80.0.1";
  baseDomain = "lachy.bepis.lol";

  libvirt = pkgs.libvirt;

  lachyNetworkXml = ''
    <network>
      <name>${networkName}</name>
      <bridge name='virbr-lachy'/>
      <forward mode='nat'/>
      <ip address='${hostIp}' netmask='255.255.255.0'>
        <dhcp>
          <range start='10.80.0.100' end='10.80.0.200'/>
          <host mac='${vmMac}' name='${vmName}' ip='${vmIp}'/>
        </dhcp>
      </ip>
    </network>
  '';

  lachyVmXml = ''
    <domain type='kvm'>
      <name>${vmName}</name>
      <memory unit='MiB'>4096</memory>
      <currentMemory unit='MiB'>4096</currentMemory>
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
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>restart</on_crash>
      <devices>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap'/>
          <source file='${vmDiskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${installIsoPath}'/>
          <target dev='sda' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <mac address='${vmMac}'/>
          <source network='${networkName}'/>
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
  '';

  ensureLachyVmScript = ''
    set -euo pipefail

    mkdir -p "${vmStorageRoot}"

    cat > "${networkXmlPath}" <<'EOF'
    ${lachyNetworkXml}
    EOF

    if ${libvirt}/bin/virsh net-info "${networkName}" >/dev/null 2>&1; then
      echo "Network '${networkName}' already exists; skipping define"
    else
      ${libvirt}/bin/virsh net-define "${networkXmlPath}"
    fi

    if ! ${libvirt}/bin/virsh net-info "${networkName}" | ${pkgs.gnugrep}/bin/grep -q "Active:.*yes"; then
      ${libvirt}/bin/virsh net-start "${networkName}"
    fi
    ${libvirt}/bin/virsh net-autostart "${networkName}"

    if [ ! -e "${installIsoPath}" ]; then
      ${pkgs.curl}/bin/curl -fL "${installIsoUrl}" -o "${installIsoPath}"
    fi

    if [ ! -e "${vmDiskPath}" ]; then
      ${pkgs.qemu}/bin/qemu-img create -f qcow2 "${vmDiskPath}" 200G
    fi

    cat > "${vmXmlPath}" <<'EOF'
    ${lachyVmXml}
    EOF

    if ${libvirt}/bin/virsh dominfo "${vmName}" >/dev/null 2>&1; then
      echo "Domain '${vmName}' already exists; skipping define"
    else
      ${libvirt}/bin/virsh define "${vmXmlPath}"
    fi

    ${libvirt}/bin/virsh autostart "${vmName}"
    if ! ${libvirt}/bin/virsh domstate "${vmName}" | ${pkgs.gnugrep}/bin/grep -q running; then
      ${libvirt}/bin/virsh start "${vmName}"
    fi
  '';
in
{
  virtualisation.libvirtd.enable = true;

  users.users.${config.hostSpec.username}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "lachy-vm-console" ''
      exec ${libvirt}/bin/virsh --connect qemu:///system console ${vmName}
    '')
    (pkgs.writeShellScriptBin "lachy-vm-display" ''
      exec ${libvirt}/bin/virsh --connect qemu:///system domdisplay ${vmName}
    '')
    (pkgs.writeShellScriptBin "lachy-vm-viewer" ''
      exec ${pkgs.virt-viewer}/bin/virt-viewer --connect qemu:///system ${vmName}
    '')
    (pkgs.writeShellScriptBin "lachy-vm-reconfigure" ''
      ${ensureLachyVmScript}
      echo "lachy-vm reconfigured from ${vmXmlPath}."
    '')
    (pkgs.writeShellScriptBin "lachy-vm-ssh-installer" ''
      exec ${pkgs.openssh}/bin/ssh nixos@${vmIp}
    '')
    libvirt
    pkgs.qemu
    pkgs.virt-manager
    pkgs.virt-viewer
  ];

  systemd.tmpfiles.rules = [
    "d ${vmStorageRoot} 0750 root root - -"
  ];

  systemd.services.lachy-vm-ensure = {
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
    script = ensureLachyVmScript;
  };

  hostedServices = [
    {
      domain = baseDomain;
      upstreamHost = vmIp;
      upstreamPort = "80";
      serverAliases = [ "*.${baseDomain}" ];
      acmeExtraDomainNames = [ "*.${baseDomain}" ];
      cloudflareExtraDomains = [ "*.${baseDomain}" ];
      webSockets = true;
    }
  ];

  networking.extraHosts = ''
    ${vmIp} ${vmName}
  '';
}
