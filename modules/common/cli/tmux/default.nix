{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.imports = [ ./home.nix ];
}
