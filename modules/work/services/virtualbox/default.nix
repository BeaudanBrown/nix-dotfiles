{ config, ... }:
{
  imports = [ ./scripts/launch_windows.nix ];
  users.extraGroups.vboxusers.members = [ config.hostSpec.username ];
  virtualisation.virtualbox.host.enable = true;
}
