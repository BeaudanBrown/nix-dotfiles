{ lib, config, ... }:
{
  imports = lib.custom.importRecursive ./.;

  # TODO: Break this out into files
  services.openssh.ports = [ config.hostSpec.sshPort ];
  programs.steam.enable = true;
}
