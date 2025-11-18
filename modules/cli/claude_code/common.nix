{
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.claude-code
  ];
}
