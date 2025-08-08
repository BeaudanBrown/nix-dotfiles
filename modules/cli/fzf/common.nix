{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.programs.fzf = {
    enable = true;
  };
}
