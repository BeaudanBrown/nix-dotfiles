{ pkgs, configLib, ... }:
{
  users.extraGroups.vboxusers.members = ["beau"];
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
    docker = {
      enable = true;
      autoPrune = { enable = true; };
    };
  };
}
