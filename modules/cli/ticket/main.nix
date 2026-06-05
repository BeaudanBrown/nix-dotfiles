{ outputs, pkgs, ... }:
{
  environment.systemPackages = [
    outputs.packages.${pkgs.stdenv.hostPlatform.system}.ticket
  ];
}
