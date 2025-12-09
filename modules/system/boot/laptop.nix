{ ... }:
{
  # To fix broken mic?
  # https://discourse.nixos.org/t/no-microphone-how-to-get-firmware-dsp-basefw-bin/38198/8
  boot.blacklistedKernelModules = [
    "snd_soc_avs"
  ];
  boot = {
    loader = {
      grub = {
        efiSupport = true;
      };
    };
  };
}
