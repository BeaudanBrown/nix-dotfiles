{ config, pkgs, ... }:
let
  project = "${config.hostSpec.home}/documents/projects/dump";
  nasIP = config.hostSpecs.nas.tailIP;
in
{
  # Transfer and rename the initial local starter BEFORE activating this mount.
  # A dedicated systemd automount avoids the shared autofs autoMaster string.
  fileSystems.${project} = {
    device = "${nasIP}:/var/lib/dump-site/project";
    fsType = "nfs";
    options = [
      "vers=4"
      "rw"
      "hard"
      "noatime"
      "proto=tcp"
      "port=2049"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
      "x-systemd.mount-timeout=30s"
    ];
  };
  environment.systemPackages = [
    (import ./package.nix { inherit pkgs; })
    pkgs.hugo
  ];
}
