{ ... }:
{
  # To fix broken mic?
  # https://discourse.nixos.org/t/no-microphone-how-to-get-firmware-dsp-basefw-bin/38198/8
  boot.blacklistedKernelModules = [
    "snd_soc_avs"
  ];

  # For zfs
  # nixpkgs.config.allowBroken = true;
  boot = {
    supportedFilesystems = [ "zfs" ];
  };
}
