{ lib, ... }:
{
  imports = lib.custom.importRecursive ./.;

  # TODO: Break this out into files
  services.openssh.ports = [ 8023 ];
  services.xserver.videoDrivers = [ "displaylink" ];
}
