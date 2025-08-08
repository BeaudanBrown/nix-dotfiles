{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.programs.oh-my-posh = {
    enable = true;
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (builtins.readFile ./config/oh-my-posh.json)
    );
    enableZshIntegration = true;
  };
}
