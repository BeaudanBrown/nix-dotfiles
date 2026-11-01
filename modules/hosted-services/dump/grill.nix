{ config, pkgs, ... }:
let
  project = "${config.hostSpec.home}/documents/projects/dump";
  nasIP = config.hostSpecs.nas.tailIP;
in
{
  # Transfer and rename the initial local starter BEFORE activating this mount.
  # Native units keep this remote path out of fstab-generator's path lookup
  # during daemon-reexec (systemd upstream issue #44396). Do not also declare
  # fileSystems.${project}. The shared autofs autoMaster remains unchanged.
  systemd.mounts = [
    {
      description = "NAS-backed dump publishing source";
      what = "${nasIP}:/var/lib/dump-site/project";
      where = project;
      type = "nfs";
      options = "vers=4,rw,hard,noatime,proto=tcp,port=2049,_netdev";
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      mountConfig.TimeoutSec = "30s";
    }
  ];
  systemd.automounts = [
    {
      description = "On-demand dump publishing source";
      where = project;
      wantedBy = [ "multi-user.target" ];
      automountConfig.TimeoutIdleSec = "300s";
    }
  ];
  environment.systemPackages = [
    (import ./package.nix { inherit pkgs; })
    pkgs.hugo
  ];
}
