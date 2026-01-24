{
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];
}
