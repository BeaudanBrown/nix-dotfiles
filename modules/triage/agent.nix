{
  inputs,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.codex
  ];
}
