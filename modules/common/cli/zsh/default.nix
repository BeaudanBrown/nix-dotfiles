{ pkgs, ... }:
{
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
}
