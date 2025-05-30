{ config, ... }:
{
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nh";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/etc/profiles/per-user/${config.hostSpec.username}/bin/shutdown";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/reboot";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${config.hostSpec.home}/.nix-profile/bin/reboot";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/shutdown";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${config.hostSpec.home}/.nix-profile/bin/shutdown";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
