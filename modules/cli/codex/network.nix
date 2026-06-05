{
  inputs,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.codex
  ];
}
