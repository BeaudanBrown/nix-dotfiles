{ config, lib, ... }:
{
  # All users inherit the system's stateVersion
  hm.all.home.stateVersion = lib.mkDefault (config.system.stateVersion or "23.05");
}
