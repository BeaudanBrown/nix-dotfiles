{ ... }:
{
  # Hibernation support
  boot.resumeDevice = "/dev/mapper/encrypted-nixos";
  boot.kernelParams = [ "resume_offset=28058880" ];
}
