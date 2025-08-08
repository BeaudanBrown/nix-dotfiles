{ config, lib, ... }:
{
  home-manager.users.${config.hostSpec.username}.home.stateVersion = lib.mkDefault (
    config.system.stateVersion or "23.05"
  );
}
