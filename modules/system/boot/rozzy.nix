{ lib, ... }:
{
  boot = {
    kernelParams = [
      "console=ttyS0,19200n8"
      "net.ifnames=0"
    ];
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = true;
        device = "nodev";
        forceInstall = true;
        configurationLimit = 5;
        extraConfig = ''
          serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1;
          terminal_input serial;
          terminal_output serial
        '';
      };
      timeout = lib.mkOverride 60 10;
    };
  };
}
