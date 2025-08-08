{ config, lib, ... }:
{
  hm.home.stateVersion = lib.mkDefault (config.system.stateVersion or "23.05");
}
