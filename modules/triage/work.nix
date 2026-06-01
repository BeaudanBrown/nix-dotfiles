{
  inputs,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    inputs.complix.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.devenv
  ];
}
