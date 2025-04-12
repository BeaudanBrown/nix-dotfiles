{ pkgs, config, ... }:
{
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  home-manager.users.${config.hostSpec.username}.imports = [ ./home.nix ];
}
