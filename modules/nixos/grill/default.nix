{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;

  # TODO: Break this out into files
  services.openssh.ports = [ 8022 ];
  programs.steam.enable = true;
}
