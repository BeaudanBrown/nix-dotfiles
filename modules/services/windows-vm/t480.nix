{
  config,
  lib,
  pkgs,
  ...
}:
let
  vmName = "windows";
  vmStorageRoot = "${config.hostSpec.home}/VM";
  vmDiskPath = "${vmStorageRoot}/${vmName}.qcow2";
  vmXmlPath = "${vmStorageRoot}/${vmName}.xml";
  windowsIsoPath = "${vmStorageRoot}/iso/windows.iso";
  virtioIsoPath = "${vmStorageRoot}/iso/virtio-win.iso";

  libvirt = pkgs.libvirt;
  libvirtShellArg = lib.escapeShellArg;

  windowsVmXml = ''
    <domain type='kvm'>
      <name>${vmName}</name>
      <firmware>
        <feature enabled='yes' name='secure-boot'/>
        <feature enabled='yes' name='enrolled-keys'/>
      </firmware>
      <memory unit='MiB'>10240</memory>
      <currentMemory unit='MiB'>10240</currentMemory>
      <vcpu placement='static'>4</vcpu>
      <cpu mode='host-passthrough' check='none' migratable='off'>
        <feature policy='require' name='vmx'/>
      </cpu>
      <os firmware='efi'>
        <type arch='x86_64' machine='q35'>hvm</type>
        <boot dev='hd'/>
        <boot dev='cdrom'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
          <vpindex state='on'/>
          <runtime state='on'/>
          <synic state='on'/>
          <stimer state='on'>
            <direct state='on'/>
          </stimer>
          <reset state='on'/>
          <frequencies state='on'/>
          <tlbflush state='on'/>
          <ipi state='on'/>
          <evmcs state='on'/>
        </hyperv>
        <vmport state='off'/>
        <smm state='on'/>
      </features>
      <clock offset='localtime'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
        <timer name='hypervclock' present='yes'/>
      </clock>
      <pm>
        <suspend-to-mem enabled='no'/>
        <suspend-to-disk enabled='no'/>
      </pm>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>restart</on_crash>
      <devices>
        <emulator>${pkgs.qemu}/bin/qemu-system-x86_64</emulator>
        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap'/>
          <source file='${vmDiskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${windowsIsoPath}'/>
          <target dev='sda' bus='sata'/>
          <readonly/>
        </disk>
        <disk type='file' device='cdrom'>
          <driver name='qemu' type='raw'/>
          <source file='${virtioIsoPath}'/>
          <target dev='sdb' bus='sata'/>
          <readonly/>
        </disk>
        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>
        <input type='tablet' bus='usb'/>
        <input type='keyboard' bus='usb'/>
        <graphics type='spice' autoport='yes' listen='127.0.0.1'>
          <listen type='address' address='127.0.0.1'/>
        </graphics>
        <video>
          <model type='virtio' heads='1' primary='yes'/>
        </video>
        <sound model='ich9'/>
        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>
        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>
        <rng model='virtio'>
          <backend model='random'>/dev/urandom</backend>
        </rng>
      </devices>
    </domain>
  '';

  windowsVmEnsure = pkgs.writeShellApplication {
    name = "windows-vm-ensure";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      libvirt
      qemu
    ];
    text = ''
      set -euo pipefail

      mkdir -p ${libvirtShellArg vmStorageRoot} ${libvirtShellArg "${vmStorageRoot}/iso"}

      if ! virsh --connect qemu:///system net-info default >/dev/null 2>&1; then
        echo "libvirt default network is unavailable" >&2
        exit 1
      fi

      if ! virsh --connect qemu:///system net-info default | grep -q "Active:.*yes"; then
        virsh --connect qemu:///system net-start default
      fi
      virsh --connect qemu:///system net-autostart default

      if [ ! -e ${libvirtShellArg vmDiskPath} ]; then
        qemu-img create -f qcow2 ${libvirtShellArg vmDiskPath} 120G
      fi

      if [ ! -e ${libvirtShellArg windowsIsoPath} ]; then
        echo "Windows ISO not found at ${windowsIsoPath}" >&2
        echo "Place the installer ISO there, then rerun: windows-vm-ensure" >&2
        exit 1
      fi

      if [ ! -e ${libvirtShellArg virtioIsoPath} ]; then
        echo "VirtIO driver ISO not found at ${virtioIsoPath}" >&2
        echo "Download virtio-win.iso and place it there, then rerun: windows-vm-ensure" >&2
        exit 1
      fi

      cat > ${libvirtShellArg vmXmlPath} <<'EOF'
      ${windowsVmXml}
      EOF

      virsh --connect qemu:///system define ${libvirtShellArg vmXmlPath}

      virsh --connect qemu:///system autostart --disable ${libvirtShellArg vmName} >/dev/null 2>&1 || true
      echo "Windows VM defined from ${vmXmlPath}."
    '';
  };
in
{
  boot.extraModprobeConfig = lib.mkAfter ''
    options kvm_intel nested=1
  '';

  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };

  users.users.${config.hostSpec.username}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    windowsVmEnsure
    (writeShellScriptBin "windows-vm-start" ''
      ${windowsVmEnsure}/bin/windows-vm-ensure
      if ! ${libvirt}/bin/virsh --connect qemu:///system domstate ${vmName} | ${gnugrep}/bin/grep -q running; then
        ${libvirt}/bin/virsh --connect qemu:///system start ${vmName}
      fi
    '')
    (writeShellScriptBin "windows-vm-viewer" ''
      display_uri="$(${libvirt}/bin/virsh --connect qemu:///system domdisplay ${vmName})"
      if [ -z "$display_uri" ]; then
        echo "No display URI found for ${vmName}. Is the VM running?" >&2
        exit 1
      fi
      exec ${virt-viewer}/bin/remote-viewer --title=windows --full-screen "$display_uri"
    '')
    (writeShellScriptBin "windows-vm-manager" ''
      exec ${virt-manager}/bin/virt-manager --connect qemu:///system --show-domain-console ${vmName}
    '')
    (writeShellScriptBin "windows-vm-stop" ''
      exec ${libvirt}/bin/virsh --connect qemu:///system shutdown ${vmName}
    '')
    (writeShellScriptBin "windows-vm-snapshot" ''
      set -euo pipefail
      name="''${1:-pre-test}"
      exec ${libvirt}/bin/virsh --connect qemu:///system snapshot-create-as ${vmName} "$name"
    '')
    (writeShellScriptBin "windows-vm-snapshots" ''
      exec ${libvirt}/bin/virsh --connect qemu:///system snapshot-list ${vmName}
    '')
    (writeShellScriptBin "windows-vm-restore" ''
      set -euo pipefail
      name="''${1:?snapshot name required}"
      exec ${libvirt}/bin/virsh --connect qemu:///system snapshot-revert ${vmName} "$name"
    '')
    libvirt
    qemu
    spice-gtk
    swtpm
    virt-manager
    virt-viewer
  ];

  systemd.tmpfiles.rules = [
    "d ${vmStorageRoot} 0750 ${config.hostSpec.username} users - -"
    "d ${vmStorageRoot}/iso 0750 ${config.hostSpec.username} users - -"
  ];
}
