{ config, lib, ... }:
{
  hm.primary.programs.direnv = {
    config = {
      whitelist = {
        prefix = lib.mkForce [
          "${config.hostSpec.home}/host"
        ];
      };
    };
  };
}
