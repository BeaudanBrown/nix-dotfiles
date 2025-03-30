{ pkgs, ... }:
{
  environment.variables = {
    LOG_ICONS = "true";
  };

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];
}
