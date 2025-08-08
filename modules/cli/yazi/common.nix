{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };
}
