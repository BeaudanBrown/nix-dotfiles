{ config, ... }:
{
  imports = [ ./scripts/launch_windows.nix ];
  users.extraGroups.vboxusers.members = [ config.hostSpec.username ];
  virtualisation = {
    virtualbox = {
      guest = {
        # Enabling this causes slow rebuild (potentially hanging while waiting for credentials?)
        enable = false;
        dragAndDrop = true;
      };
      host = {
        enable = true;
      };
    };
  };
}
